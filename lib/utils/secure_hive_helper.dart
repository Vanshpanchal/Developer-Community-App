import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Secure storage utility for encrypted Hive boxes.
/// Uses flutter_secure_storage to manage encryption keys.
class SecureHiveHelper {
  SecureHiveHelper._();
  static final SecureHiveHelper instance = SecureHiveHelper._();

  static const _secureStorage = FlutterSecureStorage();
  static const _encryptionKeyName = 'hive_encryption_key';

  List<int>? _encryptionKey;

  /// Get or generate encryption key for Hive boxes
  Future<List<int>> getEncryptionKey() async {
    if (_encryptionKey != null) return _encryptionKey!;

    final existingKey = await _secureStorage.read(key: _encryptionKeyName);
    
    if (existingKey != null) {
      _encryptionKey = base64Url.decode(existingKey);
    } else {
      // Generate a new secure key
      _encryptionKey = Hive.generateSecureKey();
      await _secureStorage.write(
        key: _encryptionKeyName,
        value: base64Url.encode(_encryptionKey!),
      );
    }
    
    return _encryptionKey!;
  }

  /// Open an encrypted Hive box
  Future<Box<T>> openEncryptedBox<T>(String name) async {
    final key = await getEncryptionKey();
    return await Hive.openBox<T>(
      name,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  /// Open an encrypted lazy Hive box (for large datasets)
  Future<LazyBox<T>> openEncryptedLazyBox<T>(String name) async {
    final key = await getEncryptionKey();
    return await Hive.openLazyBox<T>(
      name,
      encryptionCipher: HiveAesCipher(key),
    );
  }
}
