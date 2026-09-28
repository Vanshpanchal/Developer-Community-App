import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'api_key_manager.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'services/secrets_service.dart';

/// Centralized AI helper for code review, summaries, portfolio, complexity, and repo analysis.
class AIService {
  AIService._internal();
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;

  static const String missingKeyMessage =
      'No Gemini API key found. Set your key in profile settings to enable AI features.';

  static const String noModelsMessage =
      'No AI models are configured right now. Please try again later.';

  /// Synchronous local cache of selected model. Use this for instant UI state reading.
  String get cachedSelectedModel {
    final box = GetStorage();
    return box.read<String>('gemini_model') ?? 'Not selected';
  }

  /// The model to call: the user's choice if it is still in
  /// `Secrets/gemini.availableModels`, otherwise the first model in that list.
  /// Returns null when the list is empty or cannot be loaded.
  Future<String?> getSelectedModel() async {
    final available = await getAvailableModels();
    if (available.isEmpty) return null;

    final remoteModel = await SecretsService.instance.loadSelectedModel();
    final localModel = GetStorage().read<String>('gemini_model');
    final chosen = [remoteModel, localModel].firstWhere(
      (m) => m != null && available.contains(m),
      orElse: () => available.first,
    )!;
    if (chosen != localModel) GetStorage().write('gemini_model', chosen);
    return chosen;
  }

  /// Loads selected model from Firebase User doc and caches locally.
  Future<void> syncModelFromFirebase() async {
    // Sync user's selected model
    final remoteModel = await SecretsService.instance.loadSelectedModel();
    if (remoteModel != null && remoteModel.isNotEmpty) {
      final box = GetStorage();
      await box.write('gemini_model', remoteModel);
    }
  }

  /// Sets the model locally AND persists to Firebase User doc.
  Future<void> setModel(String model) async {
    final box = GetStorage();
    await box.write('gemini_model', model);
    await SecretsService.instance.saveSelectedModel(model);
  }

  List<String>? _availableModelsCache;

  /// Models listed in `Secrets/gemini.availableModels` — the only source of
  /// model names. Cached for the session once a non-empty list is loaded.
  Future<List<String>> getAvailableModels({bool forceRefresh = false}) async {
    if (!forceRefresh && _availableModelsCache != null) {
      return _availableModelsCache!;
    }
    final remoteModels = await SecretsService.instance.getAvailableModels();
    final models = (remoteModels ?? const <String>[])
        .where((m) => m.trim().isNotEmpty)
        .toList();
    if (models.isNotEmpty) _availableModelsCache = models;
    return models;
  }

  Future<bool> _ensureApiKey() async {
    final key = await ApiKeyManager.instance.getLocalKey();
    return key != null && key.trim().isNotEmpty;
  }

  Future<String?> _getApiKey() async {
    return await ApiKeyManager.instance.getLocalKey();
  }

  Future<String> reviewCode({required String code, String? context}) async {
    if (!await _ensureApiKey()) return missingKeyMessage;
    if (code.trim().isEmpty) return 'No code provided for review.';
    final prompt = _buildCodeReviewPrompt(code: code, context: context);
    return _generate(prompt);
  }

  Future<String> summarizeThread({
    required String title,
    required String description,
    required List<Map<String, dynamic>> replies,
    int maxReplies = 30,
  }) async {
    if (!await _ensureApiKey()) return missingKeyMessage;
    final limited = replies.take(maxReplies).toList();
    final prompt = _buildThreadSummaryPrompt(
        title: title, description: description, replies: limited);
    return _generate(prompt);
  }

  Future<String> analyzeRepository({
    required String repoUrl,
    String? readme,
    Map<String, String>? files,
  }) async {
    if (!await _ensureApiKey()) return missingKeyMessage;
    final prompt = _buildRepoAnalysisPrompt(
        repoUrl: repoUrl, readme: readme, files: files ?? {});
    return _generate(prompt);
  }

  Future<String> generatePortfolioSummary({
    required Map<String, dynamic> stats,
    Map<String, dynamic>? github,
    String? userHandle,
  }) async {
    if (!await _ensureApiKey()) return missingKeyMessage;
    final prompt = _buildPortfolioPrompt(
        stats: stats, github: github, userHandle: userHandle);
    return _generate(prompt);
  }

  Future<String> analyzeComplexity(
      {required String code, String? language, String? context}) async {
    if (!await _ensureApiKey()) return missingKeyMessage;
    if (code.trim().isEmpty) return 'No code provided.';
    final prompt = _buildComplexityPrompt(
        code: code, language: language, context: context);
    return _generate(prompt);
  }

  /// General text generation method for chat or arbitrary prompts
  Future<String> generateText(String prompt) async {
    return _generate(prompt);
  }

  Future<String> _generate(String prompt) async {
    final result = await _request([
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ]
      }
    ]);
    return result.text;
  }

  /// Multi-turn chat. [history] is oldest first and should end with the
  /// user's new message. Only the last [maxTurns] turns are sent.
  /// `ok` is false when [text] is an error message rather than a reply.
  Future<({String text, bool ok})> chat(
    List<({String text, bool isUser})> history, {
    int maxTurns = 20,
  }) {
    final recent = history.length > maxTurns
        ? history.sublist(history.length - maxTurns)
        : history;
    return _request([
      for (final turn in recent)
        {
          'role': turn.isUser ? 'user' : 'model',
          'parts': [
            {'text': turn.text}
          ]
        }
    ]);
  }

  Future<({String text, bool ok})> _request(
      List<Map<String, dynamic>> contents) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null || apiKey.trim().isEmpty) return (text: missingKeyMessage, ok: false);

      final model = await getSelectedModel();
      if (model == null) return (text: noModelsMessage, ok: false);
      final endpoint =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

      final uri = Uri.parse(endpoint);
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({'contents': contents}),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content is Map &&
              content['parts'] is List &&
              content['parts'].isNotEmpty) {
            final text = content['parts'][0]['text'];
            if (text is String && text.trim().isNotEmpty) {
              return (text: text.trim(), ok: true);
            }
          }
        }
        return (text: 'No response generated.', ok: false);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return (text: 'Authentication error (${response.statusCode}). Check that your API key is valid and has access.', ok: false);
      }
      if (response.statusCode == 429) {
        return (text: 'Rate limit reached. Please wait and try again.', ok: false);
      }
      if (response.statusCode >= 500) {
        return (text: 'Service unavailable (${response.statusCode}). Retry later.', ok: false);
      }
      return (text: 'Error (${response.statusCode}): ${response.reasonPhrase ?? 'Unknown'}', ok: false);
    } on TimeoutException {
      return (text: 'Request timed out. Please check your network connection and try again.', ok: false);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Gemini request failed: $e\n$st');
      return (text: 'Connection error. Please try again.', ok: false);
    }
  }

  String _buildPortfolioPrompt({
    required Map<String, dynamic> stats,
    Map<String, dynamic>? github,
    String? userHandle,
  }) {
    final buf = StringBuffer();
    buf.writeln(
        'Create a concise, professional GitHub-Flavored Markdown developer portfolio summary.');
    buf.writeln('Sections (use headings, omit empty):');
    buf.writeln('## Profile Snapshot');
    buf.writeln('## Key Activity Metrics');
    buf.writeln('## Tech & Topic Focus (from tag frequency)');
    buf.writeln('## Community Impact');
    buf.writeln('## GitHub Highlights');
    buf.writeln('## Suggested Growth Areas');
    buf.writeln('## Short Value Proposition (1 sentence)');
    buf.writeln('Keep under 260 words.');
    if (userHandle != null) buf.writeln('User Handle: $userHandle');
    buf.writeln('App Stats JSON: ${jsonEncode(stats)}');
    if (github != null) buf.writeln('GitHub Stats JSON: ${jsonEncode(github)}');
    buf.writeln('Use bullet lists where natural. Avoid generic fluff.');
    return buf.toString();
  }

  String _buildRepoAnalysisPrompt({
    required String repoUrl,
    String? readme,
    required Map<String, String> files,
  }) {
    final buf = StringBuffer();
    buf.writeln('You are an expert open-source project analyst.');
    buf.writeln('Analyze the repository at: $repoUrl');
    buf.writeln(
        'Produce ONLY GitHub-Flavored Markdown with these sections (use headings):');
    buf.writeln('## Tech Stack');
    buf.writeln('## Complexity Level');
    buf.writeln('- Choose exactly one: Beginner / Intermediate / Advanced');
    buf.writeln('## Rationale for Complexity (2-4 bullets)');
    buf.writeln('## Suggested Contribution Areas');
    buf.writeln('## Onboarding Steps (actionable)');
    buf.writeln('## Potential Risks / Gaps');
    buf.writeln('## Quick Win Ideas');
    buf.writeln('Keep total under 300 words.');
    if (readme != null && readme.trim().isNotEmpty) {
      buf.writeln(
          '\nREADME (truncated):\n```md\n${_truncate(readme, 3000)}\n```');
    }
    if (files.isNotEmpty) {
      buf.writeln('\nKey Files (truncated):');
      files.forEach((name, content) {
        buf.writeln('\n### $name');
        buf.writeln('```\n${_truncate(content, 1000)}\n```');
      });
    }
    return buf.toString();
  }

  String _buildComplexityPrompt(
      {required String code, String? language, String? context}) {
    final lang = language ?? 'code';
    return '''You are an expert algorithm analyst.
Given the following $lang snippet, produce a concise complexity analysis.

Sections (omit if empty):
## Overall Complexity
- Big-O Time (worst & typical)
- Big-O Space (auxiliary)
## Per Function / Method
| Function | Time | Space | Notes |
|----------|------|-------|-------|
List each top-level function/method (or main logical block) with estimated time/space.
## Hotspots / Bottlenecks
Bullet list of any loops, nested loops, recursion, heavy calls.
## Optimization Suggestions
Actionable, concise suggestions.

Context: ${context ?? 'N/A'}

Code:
```$lang
$code
```
Keep under 220 words. Use GitHub-Flavored Markdown only.''';
  }

  String _truncate(String input, int max) {
    if (input.length <= max) return input;
    return '${input.substring(0, max)}\n...<truncated>';
  }

  String _buildCodeReviewPrompt({required String code, String? context}) {
    return '''You are an expert software engineering reviewer.
Provide a concise, actionable code review. Use the following sections (omit a section if not applicable):
1. Overview (1-2 sentences)
2. Strengths (bullet list)
3. Potential Issues / Bugs (bullet list)
4. Complexity & Readability (brief)
5. Security / Edge Cases (brief)
6. Performance considerations (if any)
7. Suggested Improvements (bullet list with example snippets)
8. Summary (single concise sentence)

Context:
${context ?? 'N/A'}

Code (fenced block):
```dart
$code
```
Keep output under ~350 words.
''';
  }

  String _buildThreadSummaryPrompt({
    required String title,
    required String description,
    required List<Map<String, dynamic>> replies,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are summarizing a developer discussion thread.');
    buffer.writeln(
        'Return ONLY valid GitHub-Flavored Markdown with the following section order.');
    buffer.writeln('Use concise language; total < 230 words.');
    buffer.writeln('Sections (omit if not applicable):');
    buffer.writeln('## High-Level Summary');
    buffer.writeln('## Key Points (bullets)');
    buffer.writeln('## Accepted / Proposed Solution');
    buffer.writeln('## Unresolved Questions');
    buffer.writeln('## Recommended Next Actions');
    buffer.writeln('Do not wrap the entire output in code fences.');
    buffer.writeln('\nContext Title: $title');
    buffer.writeln('Original Description:\n$description');
    buffer.writeln('\nReplies (user: text):');
    for (final r in replies) {
      final user = r['user_name'] ?? 'user';
      final text = (r['reply'] ?? '').toString().replaceAll('\n', ' ');
      final accepted = r['accepted'] == true ? ' (accepted)' : '';
      buffer.writeln('- $user$accepted: $text');
    }
    return buffer.toString();
  }
}
