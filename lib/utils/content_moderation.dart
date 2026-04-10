import 'package:cloud_firestore/cloud_firestore.dart';

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
    return analyzeSubmission(
      title: title,
      description: description,
      tags: tags,
      code: code,
    );
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
    return analyzeReply(reply);
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
}
