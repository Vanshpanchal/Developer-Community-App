import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Fetches app-wide secrets from the `secrets` Firestore collection.
/// In future, all API keys and config values will be stored here.
///
/// Firestore structure:
///   secrets/
///     gemini/
///       apiKey: "..."
class SecretsService {
  SecretsService._();
  static final SecretsService instance = SecretsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Gemini secrets
  // ---------------------------------------------------------------------------

  /// Fetches the shared Gemini API key from Firestore (secrets/gemini).
  Future<String?> getGeminiApiKey() async {
    try {
      final doc = await _db.collection('Secrets').doc('gemini').get();
      return doc.data()?['apiKey'] as String?;
    } catch (e) {
      debugPrint('SecretsService: failed to fetch gemini key: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // User model preference & Available Models
  // ---------------------------------------------------------------------------

  /// Fetches available Gemini models from the shared secrets/gemini config.
  Future<List<String>?> getAvailableModels() async {
    try {
      final doc = await _db.collection('Secrets').doc('gemini').get();
      final models = doc.data()?['availableModels'] as List<dynamic>?;
      debugPrint("Available models___: $models");
      if (models != null) {
        return models.cast<String>();
      }
    } catch (e) {
      debugPrint('SecretsService: failed to load available models: $e');
    }
    return null;
  }

  /// Saves the selected Gemini model name to the authenticated user's document.
  Future<void> saveSelectedModel(String model) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('User').doc(uid).update({'selectedAiModel': model});
    } catch (e) {
      debugPrint('SecretsService: failed to save model: $e');
    }
  }

  /// Loads the selected Gemini model from the authenticated user's document.
  Future<String?> loadSelectedModel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('User').doc(uid).get();
      return doc.data()?['selectedAiModel'] as String?;
    } catch (e) {
      debugPrint('SecretsService: failed to load model: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Avatar — persist url + dominant color on the User document
  // ---------------------------------------------------------------------------

  /// Updates `profilePicture` and (optionally) `profileDominantColor` on the
  /// User document in a single Firestore write.
  ///
  /// [bgHex] — the 6-char hex of the avatar's background color (e.g. "b6e3f4").
  /// When provided the integer colour value is stored as [profileDominantColor]
  /// so the profile header gradient and all avatar-display widgets update
  /// immediately on next load without re-running palette_generator.
  Future<void> saveAvatarUrl(String url, {String? bgHex}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fields = <String, dynamic>{'profilePicture': url};

    // Derive dominant color from the avatar background hex when available
    if (bgHex != null && bgHex.length == 6) {
      final colorInt = _hexToColorInt(bgHex);
      if (colorInt != null) {
        fields['profileDominantColor'] = colorInt;
      }
    }

    try {
      await _db.collection('User').doc(uid).update(fields);
    } catch (e) {
      debugPrint('SecretsService: failed to save avatar: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts a 6-char hex string (e.g. "b6e3f4") to a Flutter Color int
  /// (0xFFRRGGBB) suitable for storing in Firestore and reading back via
  /// `Color(int)`.
  int? _hexToColorInt(String hex) {
    try {
      return int.parse('FF${hex.toUpperCase()}', radix: 16);
    } catch (_) {
      return null;
    }
  }
}
