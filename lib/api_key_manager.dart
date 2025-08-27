import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages user-provided Gemini API keys.
/// - Stores the raw key only locally using secure storage.
/// - Stores a SHA256 hash of the key in Firestore for verification / presence.
/// - Exposes retrieval for AIService; if key missing returns null.
class ApiKeyManager {
  ApiKeyManager._();
  static final ApiKeyManager instance = ApiKeyManager._();

  static const _secure = FlutterSecureStorage();
  static const _localKeyName = 'gemini_api_key';

  Future<void> saveUserKey(String rawKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) throw ArgumentError('API key empty');
    await _secure.write(key: _localKeyName, value: trimmed);
    final hash = sha256.convert(utf8.encode(trimmed)).toString();
    await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
      'geminiKeyHash': hash,
      'geminiKeySetAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<String?> getLocalKey() async {
    return _secure.read(key: _localKeyName);
  }

  Future<bool> hasRemoteHash() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final snap = await FirebaseFirestore.instance.collection('User').doc(user.uid).get();
    return snap.data()?['geminiKeyHash'] != null;
  }

  Future<void> clearKey() async {
    final user = FirebaseAuth.instance.currentUser;
    await _secure.delete(key: _localKeyName);
    if (user != null) {
      await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
        'geminiKeyHash': FieldValue.delete(),
        'geminiKeySetAt': FieldValue.delete(),
      });
    }
  }
}
