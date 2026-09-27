import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../utils/app_logger.dart';

/// Service to handle encryption/decryption of sensitive data
///
/// Features:
/// - AES-256-CBC encryption with unique cryptographically random IV per encryption
/// - Secure key management using Flutter Secure Storage
/// - Hive database encryption
/// - Field-level encryption for Firestore data
class EncryptionService {
  EncryptionService._internal();
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _encryptionKeyName = 'app_encryption_key';
  static const String _hiveKeyName = 'hive_encryption_key';

  enc.Encrypter? _encrypter;
  enc.Key? _key;
  bool _initialized = false;

  /// Initialize the encryption service
  /// Must be called before using any encryption methods
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get or create encryption key
      String? keyString = await _secureStorage.read(key: _encryptionKeyName);

      if (keyString == null) {
        // Generate new 256-bit AES key
        final key = enc.Key.fromSecureRandom(32);
        keyString = base64.encode(key.bytes);
        await _secureStorage.write(key: _encryptionKeyName, value: keyString);
      }

      _key = enc.Key(base64.decode(keyString));
      _encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
      _initialized = true;
    } catch (e) {
      AppLogger.error('Encryption initialization error', e);
      rethrow;
    }
  }

  /// Get or create Hive encryption key for database encryption
  Future<List<int>> getHiveEncryptionKey() async {
    try {
      String? keyString = await _secureStorage.read(key: _hiveKeyName);

      if (keyString == null) {
        // Generate 256-bit key for Hive
        final random = Random.secure();
        final key = List<int>.generate(32, (_) => random.nextInt(256));
        keyString = base64.encode(key);
        await _secureStorage.write(key: _hiveKeyName, value: keyString);
        return key;
      }

      return base64.decode(keyString);
    } catch (e) {
      AppLogger.error('Hive key generation error', e);
      rethrow;
    }
  }

  /// Encrypt a string value with a fresh random 16-byte IV prepended to output
  /// Returns base64 encoded string containing [IV (16 bytes) + Ciphertext]
  String encryptString(String plainText) {
    if (!_initialized || _encrypter == null) {
      throw StateError(
          'EncryptionService not initialized. Call initialize() first.');
    }

    if (plainText.isEmpty) return '';

    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);

      // Prepend 16-byte IV to ciphertext bytes
      final combined = Uint8List(16 + encrypted.bytes.length);
      combined.setRange(0, 16, iv.bytes);
      combined.setRange(16, combined.length, encrypted.bytes);

      return base64.encode(combined);
    } catch (e) {
      AppLogger.error('Encryption error: $e');
      rethrow;
    }
  }

  /// Decrypt a base64 encoded string containing [IV (16 bytes) + Ciphertext]
  /// Returns original plaintext
  String decryptString(String encryptedBase64) {
    if (!_initialized || _encrypter == null) {
      throw StateError(
          'EncryptionService not initialized. Call initialize() first.');
    }

    if (encryptedBase64.isEmpty) return '';

    try {
      final combined = base64.decode(encryptedBase64);
      if (combined.length <= 16) {
        throw ArgumentError('Invalid encrypted payload: too short');
      }

      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      final iv = enc.IV(Uint8List.fromList(ivBytes));
      final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      AppLogger.error('Decryption error: $e');
      rethrow;
    }
  }

  /// Encrypt sensitive fields in a Map before saving to Firestore
  Map<String, dynamic> encryptFields(
    Map<String, dynamic> data,
    List<String> fieldsToEncrypt,
  ) {
    final encryptedData = Map<String, dynamic>.from(data);

    for (final field in fieldsToEncrypt) {
      if (encryptedData.containsKey(field) && encryptedData[field] is String) {
        final value = encryptedData[field] as String;
        if (value.isNotEmpty) {
          encryptedData[field] = encryptString(value);
          encryptedData['${field}_encrypted'] = true;
        }
      }
    }

    return encryptedData;
  }

  /// Decrypt sensitive fields from Firestore data
  Map<String, dynamic> decryptFields(
    Map<String, dynamic> data,
    List<String> fieldsToDecrypt,
  ) {
    final decryptedData = Map<String, dynamic>.from(data);

    for (final field in fieldsToDecrypt) {
      if (decryptedData['${field}_encrypted'] == true &&
          decryptedData.containsKey(field) &&
          decryptedData[field] is String) {
        final value = decryptedData[field] as String;
        if (value.isNotEmpty) {
          decryptedData[field] = decryptString(value);
        }
      }
    }

    return decryptedData;
  }

  /// Hash a value using SHA-256
  String hash(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a secure random token
  String generateSecureToken({int length = 32}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64.encode(values);
  }

  /// Clear all encryption keys
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _encryptionKeyName);
    await _secureStorage.delete(key: _hiveKeyName);
    _initialized = false;
    _encrypter = null;
    _key = null;
  }

  /// Check if encryption is initialized
  bool get isInitialized => _initialized;
}

/// Hive Encryption Cipher using AES-256
class HiveAesCipher implements HiveCipher {
  final List<int> _key;

  HiveAesCipher(this._key) {
    if (_key.length != 32) {
      throw ArgumentError('Encryption key must be 32 bytes for AES-256');
    }
  }

  @override
  int decrypt(
      Uint8List inp, int inpOff, int inpLength, Uint8List out, int outOff) {
    try {
      final key = enc.Key(Uint8List.fromList(_key));
      final iv = enc.IV(inp.sublist(inpOff, inpOff + 16));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final encrypted = enc.Encrypted(
        inp.sublist(inpOff + 16, inpOff + inpLength),
      );

      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      out.setRange(outOff, outOff + decrypted.length, decrypted);

      return decrypted.length;
    } catch (e) {
      AppLogger.error('Hive decryption error', e);
      rethrow;
    }
  }

  @override
  int encrypt(
      Uint8List inp, int inpOff, int inpLength, Uint8List out, int outOff) {
    try {
      final key = enc.Key(Uint8List.fromList(_key));
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final encrypted = encrypter.encryptBytes(
        inp.sublist(inpOff, inpOff + inpLength),
        iv: iv,
      );

      // Store IV at the beginning
      out.setRange(outOff, outOff + 16, iv.bytes);
      out.setRange(
          outOff + 16, outOff + 16 + encrypted.bytes.length, encrypted.bytes);

      return 16 + encrypted.bytes.length;
    } catch (e) {
      AppLogger.error('Hive encryption error', e);
      rethrow;
    }
  }

  @override
  int maxEncryptedSize(Uint8List inp) {
    // IV (16 bytes) + encrypted data + padding
    return 16 + inp.length + 16;
  }

  @override
  int calculateKeyCrc() {
    // 32-bit polynomial CRC for key checksum
    int crc = 0xFFFFFFFF;
    for (final byte in _key) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return ~crc & 0xFFFFFFFF;
  }
}
