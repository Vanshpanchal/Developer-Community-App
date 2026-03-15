import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_key_manager.dart';

enum ModerationStatus {
  approved,
  lowQuality,
  blocked,
}

class ContentModerationResult {
  const ContentModerationResult({
    required this.status,
    required this.qualityScore,
    required this.flags,
    this.source = 'heuristic',
  });

  final ModerationStatus status;
  final double qualityScore;
  final List<String> flags;
  final String source;

  bool get isBlocked => status == ModerationStatus.blocked;

  bool get shouldReject =>
      isBlocked ||
      (status == ModerationStatus.lowQuality && qualityScore < 0.35);

  bool get shouldDeprioritize =>
      status == ModerationStatus.lowQuality || qualityScore < 0.7;

  String get statusKey {
    switch (status) {
      case ModerationStatus.approved:
        return 'approved';
      case ModerationStatus.lowQuality:
        return 'low_quality';
      case ModerationStatus.blocked:
        return 'blocked';
    }
  }

  String get userMessage {
    if (isBlocked) {
      return 'Please remove harmful, abusive, or unsafe language before posting.';
    }
    return 'Please enter meaningful text. Random, repetitive, or unclear phrases are not allowed.';
  }
}

class ContentModerationService {
  static const String _modelEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent';
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const Duration _minRequestSpacing = Duration(seconds: 2);
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _maxRequestsPerWindow = 8;

  static final List<RegExp> _blockedPatterns = [
    RegExp(r'\bkill yourself\b', caseSensitive: false),
    RegExp(r'\bhurt yourself\b', caseSensitive: false),
    RegExp(r'\bsuicide\b', caseSensitive: false),
    RegExp(r'\bself\s*harm\b', caseSensitive: false),
    RegExp(r'\bbomb threat\b', caseSensitive: false),
    RegExp(r'\bshoot up\b', caseSensitive: false),
    RegExp(r'\brape\b', caseSensitive: false),
    RegExp(r'\bporn\b', caseSensitive: false),
    RegExp(r'\bnudes?\b', caseSensitive: false),
    RegExp(r'\bgo back to your country\b', caseSensitive: false),
  ];
  static final List<DateTime> _requestHistory = <DateTime>[];
  static final Map<String, _CachedModerationResult> _cache =
      <String, _CachedModerationResult>{};
  static final Map<String, Future<ContentModerationResult?>> _inFlight =
      <String, Future<ContentModerationResult?>>{};

  static Future<void> _rateLimitChain = Future<void>.value();
  static DateTime? _lastRequestAt;

  static ContentModerationResult analyzeField(
    String? value, {
    required int minLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return const ContentModerationResult(
        status: ModerationStatus.lowQuality,
        qualityScore: 0,
        flags: ['empty'],
      );
    }

    if (_containsBlockedContent(text)) {
      return const ContentModerationResult(
        status: ModerationStatus.blocked,
        qualityScore: 0,
        flags: ['blocked_language'],
      );
    }

    final flags = <String>[];
    if (text.length < minLength) {
      flags.add('too_short');
    }
    if (_hasRepeatedCharacters(text)) {
      flags.add('repeated_characters');
    }
    if (_hasRepeatedWords(text)) {
      flags.add('repeated_words');
    }
    if (_looksLikeGibberish(text)) {
      flags.add('gibberish');
    }

    final qualityScore = _qualityScoreForText(text, minLength: minLength);
    final status = (flags.isEmpty && qualityScore >= 0.7)
        ? ModerationStatus.approved
        : ModerationStatus.lowQuality;

    return ContentModerationResult(
      status: status,
      qualityScore: qualityScore,
      flags: flags,
    );
  }

  static ContentModerationResult analyzeSubmission({
    required String title,
    required String description,
    List<String> tags = const [],
    String code = '',
  }) {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    final combined = [
      normalizedTitle,
      normalizedDescription,
      ...tags,
      if (code.trim().isNotEmpty) code.trim(),
    ].join(' ');

    if (_containsBlockedContent(combined)) {
      return const ContentModerationResult(
        status: ModerationStatus.blocked,
        qualityScore: 0,
        flags: ['blocked_language'],
      );
    }

    final titleCheck = analyzeField(normalizedTitle, minLength: 5);
    final descriptionCheck = analyzeField(normalizedDescription, minLength: 12);
    final flags = <String>[
      ...titleCheck.flags.where((flag) => flag != 'empty'),
      ...descriptionCheck.flags.where((flag) => flag != 'empty'),
    ];

    if (tags.isEmpty) {
      flags.add('missing_tags');
    }
    if (_looksLikeTemplateSpam(normalizedTitle, normalizedDescription)) {
      flags.add('template_spam');
    }

    final wordCount = _wordCount('$normalizedTitle $normalizedDescription');
    double qualityScore = 1.0;

    if (normalizedTitle.length < 8) qualityScore -= 0.18;
    if (normalizedDescription.length < 20) qualityScore -= 0.22;
    if (wordCount < 5) qualityScore -= 0.18;
    if (tags.isEmpty) qualityScore -= 0.10;
    if (flags.contains('repeated_characters')) qualityScore -= 0.25;
    if (flags.contains('repeated_words')) qualityScore -= 0.20;
    if (flags.contains('gibberish')) qualityScore -= 0.35;
    if (flags.contains('template_spam')) qualityScore -= 0.25;

    qualityScore = qualityScore.clamp(0.0, 1.0);

    final status = qualityScore >= 0.7 && !flags.contains('gibberish')
        ? ModerationStatus.approved
        : ModerationStatus.lowQuality;

    return ContentModerationResult(
      status: status,
      qualityScore: qualityScore,
      flags: flags.toSet().toList()..sort(),
    );
  }

  static Future<ContentModerationResult> moderateSubmission({
    required String title,
    required String description,
    List<String> tags = const [],
    String code = '',
  }) async {
    final heuristic = analyzeSubmission(
      title: title,
      description: description,
      tags: tags,
      code: code,
    );

    if (heuristic.isBlocked) {
      return heuristic;
    }

    final aiResult = await _analyzeWithGemini(
      scope: 'submission',
      payload: {
        'title': title.trim(),
        'description': description.trim(),
        'tags': tags,
        'code': code.trim(),
      },
    );

    if (aiResult == null) {
      return heuristic;
    }

    return _mergeResults(heuristic, aiResult);
  }

  static ContentModerationResult analyzeReply(String reply) {
    final result = analyzeField(reply, minLength: 6);
    if (result.isBlocked) {
      return result;
    }

    final qualityScore =
        (result.qualityScore - (_wordCount(reply) < 3 ? 0.2 : 0))
            .clamp(0.0, 1.0);

    return ContentModerationResult(
      status: qualityScore >= 0.55
          ? ModerationStatus.approved
          : ModerationStatus.lowQuality,
      qualityScore: qualityScore,
      flags: result.flags,
    );
  }

  static Future<ContentModerationResult> moderateReply(String reply) async {
    final heuristic = analyzeReply(reply);
    if (heuristic.isBlocked) {
      return heuristic;
    }

    final aiResult = await _analyzeWithGemini(
      scope: 'reply',
      payload: {
        'reply': reply.trim(),
      },
    );

    if (aiResult == null) {
      return heuristic;
    }

    return _mergeResults(heuristic, aiResult);
  }

  static double calculateFeedScore(Map<String, dynamic> data) {
    final storedQuality = (data['qualityScore'] as num?)?.toDouble();
    final derived = analyzeSubmission(
      title: data['Title']?.toString() ?? '',
      description: data['Description']?.toString() ?? '',
      tags: List<String>.from(data['Tags'] ?? const []),
      code: data['code']?.toString() ?? '',
    );

    final qualityScore =
        (storedQuality ?? derived.qualityScore).clamp(0.0, 1.0);
    final contentStatus =
        data['contentStatus']?.toString() ?? derived.statusKey;
    if (data['Report'] == true || contentStatus == 'blocked') {
      return -1;
    }

    final timestamp = data['Timestamp'];
    final createdAt = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    final ageHours = DateTime.now().difference(createdAt).inHours;
    final recencyScore = (1 / (1 + (ageHours / 72))).clamp(0.0, 1.0);

    final likesCount = (data['likescount'] as num?)?.toDouble() ?? 0.0;
    final repliesCount = _extractRepliesCount(data).toDouble();
    final engagementScore = ((likesCount * 0.7) + (repliesCount * 0.9)) / 20;

    double score = (qualityScore * 0.72) +
        (recencyScore * 0.22) +
        (engagementScore.clamp(0.0, 1.0) * 0.06);

    if (data['deprioritizeInFeed'] == true || derived.shouldDeprioritize) {
      score -= 0.30;
    }

    return score;
  }

  static int _extractRepliesCount(Map<String, dynamic> data) {
    final replies = data['Replies'];
    if (replies is List) {
      return replies.length;
    }
    final answers = data['answers'];
    if (answers is List) {
      return answers.length;
    }
    return 0;
  }

  static bool _containsBlockedContent(String text) {
    return _blockedPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static bool _hasRepeatedCharacters(String text) {
    return RegExp(r'(.)\1{4,}', caseSensitive: false).hasMatch(text);
  }

  static bool _hasRepeatedWords(String text) {
    return RegExp(r'\b(\w+)(?:\s+\1\b){2,}', caseSensitive: false)
        .hasMatch(text);
  }

  static bool _looksLikeTemplateSpam(String title, String description) {
    final combined = '$title $description'.toLowerCase();
    return combined.contains('asdf') ||
        combined.contains('qwerty') ||
        combined.contains('test test test') ||
        combined.contains('lorem ipsum');
  }

  static bool _looksLikeGibberish(String text) {
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return true;
    }

    final longTokens = tokens.where((token) => token.length >= 4).toList();
    if (longTokens.isEmpty) {
      return false;
    }

    final gibberishTokens = longTokens.where((token) {
      final uniqueChars = token.split('').toSet().length;
      final hasVowel = RegExp(r'[aeiou]').hasMatch(token);
      final uniqueRatio = uniqueChars / token.length;
      return !hasVowel || uniqueRatio < 0.35;
    }).length;

    final uniqueWords = tokens.toSet().length;
    if (text.length >= 12 && uniqueWords <= 2) {
      return true;
    }

    return (gibberishTokens / longTokens.length) >= 0.6;
  }

  static double _qualityScoreForText(String text, {required int minLength}) {
    double score = 1.0;
    final trimmed = text.trim();
    final uniqueWords = trimmed
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toSet()
        .length;

    if (trimmed.length < minLength) score -= 0.35;
    if (_hasRepeatedCharacters(trimmed)) score -= 0.30;
    if (_hasRepeatedWords(trimmed)) score -= 0.25;
    if (_looksLikeGibberish(trimmed)) score -= 0.40;
    if (trimmed.length >= minLength && uniqueWords <= 2) score -= 0.20;

    return score.clamp(0.0, 1.0);
  }

  static int _wordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .length;
  }

  static Future<ContentModerationResult?> _analyzeWithGemini({
    required String scope,
    required Map<String, dynamic> payload,
  }) async {
    final apiKey = ApiKeyManager.instance.getProjectModerationKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return null;
    }

    final cacheKey = _buildCacheKey(scope, payload);
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.result;
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing;
    }

    final future = _runSerialized(() async {
      await _waitForRateLimitSlot();

      try {
        final response = await http.post(
          Uri.parse(_modelEndpoint),
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_LOW_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_LOW_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_LOW_AND_ABOVE',
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_LOW_AND_ABOVE',
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': 220,
              'responseMimeType': 'application/json',
            },
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        _buildModerationPrompt(scope: scope, payload: payload),
                  }
                ]
              }
            ]
          }),
        );

        final parsed = _parseGeminiResponse(response);
        if (parsed != null) {
          _cache[cacheKey] = _CachedModerationResult(
            result: parsed,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
        }
        return parsed;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Gemini moderation failed: $e\n$st');
        }
        return null;
      }
    });

    _inFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static Future<T> _runSerialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _rateLimitChain;
    _rateLimitChain = completer.future;

    return previous.catchError((_) {}).then((_) async {
      try {
        return await action();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
  }

  static Future<void> _waitForRateLimitSlot() async {
    while (true) {
      final now = DateTime.now();
      _requestHistory.removeWhere(
        (timestamp) => now.difference(timestamp) >= _rateLimitWindow,
      );

      Duration waitTime = Duration.zero;
      if (_lastRequestAt != null) {
        final nextAllowed = _lastRequestAt!.add(_minRequestSpacing);
        if (nextAllowed.isAfter(now)) {
          waitTime = nextAllowed.difference(now);
        }
      }

      if (_requestHistory.length >= _maxRequestsPerWindow) {
        final retryAt = _requestHistory.first.add(_rateLimitWindow);
        final retryDelay = retryAt.difference(now);
        if (retryDelay > waitTime) {
          waitTime = retryDelay;
        }
      }

      if (waitTime <= Duration.zero) {
        final requestTime = DateTime.now();
        _requestHistory.add(requestTime);
        _lastRequestAt = requestTime;
        return;
      }

      await Future.delayed(waitTime);
    }
  }

  static String _buildCacheKey(String scope, Map<String, dynamic> payload) {
    final normalized = jsonEncode({
      'scope': scope,
      'payload': payload,
    });
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String _buildModerationPrompt({
    required String scope,
    required Map<String, dynamic> payload,
  }) {
    final scopeInstructions = scope == 'reply'
        ? 'This content is a single reply inside a developer discussion thread.'
        : 'This content is a new post or discussion shown in the main community feed.';

    return '''You are a moderation classifier for a professional developer community app.

$scopeInstructions

Moderation goals:
1. Block harmful content: hate speech, harassment, threats, violent incitement, self-harm encouragement, sexually explicit abuse, or dangerous instructions.
2. Mark low-quality content when it is mostly random, meaningless, gibberish, repetitive spam, or clearly irrelevant to a developer community discussion.
3. Do not penalize technical jargon, stack traces, code snippets, library names, abbreviations, or short tags if the content is still meaningful.

Return ONLY JSON in this exact shape:
{
  "status": "approved" | "low_quality" | "blocked",
  "qualityScore": 0.0,
  "flags": ["string"],
  "userMessage": "short message for the end user"
}

Rules:
- Use "blocked" only for unsafe or abusive content.
- Use "low_quality" for nonsense, random character strings, repetitive filler, or content too vague to be useful.
- Set qualityScore between 0 and 1 where lower means less suitable for the feed.
- Keep userMessage short and actionable.

Content to review:
${jsonEncode(payload)}''';
  }

  static ContentModerationResult? _parseGeminiResponse(http.Response response) {
    if (response.statusCode == 429 || response.statusCode >= 500) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final promptFeedback = data['promptFeedback'];
    if (promptFeedback is Map<String, dynamic> &&
        promptFeedback['blockReason'] != null) {
      return const ContentModerationResult(
        status: ModerationStatus.blocked,
        qualityScore: 0,
        flags: ['gemini_prompt_blocked'],
        source: 'gemini',
      );
    }

    if (response.statusCode != 200) {
      return null;
    }

    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }

    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) {
      return null;
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return null;
    }
    final text = parts.first['text'];
    if (text is! String || text.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final statusKey = decoded['status']?.toString() ?? 'low_quality';
    final qualityScore =
        ((decoded['qualityScore'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0);
    final flags = (decoded['flags'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];

    return ContentModerationResult(
      status: _statusFromKey(statusKey),
      qualityScore: qualityScore,
      flags: flags,
      source: 'gemini',
    );
  }

  static ModerationStatus _statusFromKey(String statusKey) {
    switch (statusKey) {
      case 'approved':
        return ModerationStatus.approved;
      case 'blocked':
        return ModerationStatus.blocked;
      case 'low_quality':
      default:
        return ModerationStatus.lowQuality;
    }
  }

  static ContentModerationResult _mergeResults(
    ContentModerationResult heuristic,
    ContentModerationResult ai,
  ) {
    if (heuristic.isBlocked || ai.isBlocked) {
      return ContentModerationResult(
        status: ModerationStatus.blocked,
        qualityScore: 0,
        flags: {...heuristic.flags, ...ai.flags}.toList()..sort(),
        source: 'hybrid',
      );
    }

    final flags = {...heuristic.flags, ...ai.flags}.toList()..sort();
    final blendedScore =
        ((heuristic.qualityScore * 0.45) + (ai.qualityScore * 0.55))
            .clamp(0.0, 1.0);

    final status = ai.status == ModerationStatus.lowQuality ||
            heuristic.status == ModerationStatus.lowQuality ||
            blendedScore < 0.7
        ? ModerationStatus.lowQuality
        : ModerationStatus.approved;

    return ContentModerationResult(
      status: status,
      qualityScore: status == ModerationStatus.lowQuality
          ? blendedScore.clamp(0.0, 0.69)
          : blendedScore,
      flags: flags,
      source: 'hybrid',
    );
  }
}

class _CachedModerationResult {
  const _CachedModerationResult({
    required this.result,
    required this.expiresAt,
  });

  final ContentModerationResult result;
  final DateTime expiresAt;
}
