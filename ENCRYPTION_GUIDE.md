# 🔐 Data Encryption Guide

## Overview

DevSphere implements multiple layers of encryption to protect your data:

### 1. **Firebase Built-in Encryption**

- ✅ **Data in Transit**: All data transferred between your device and Firebase is encrypted using HTTPS/TLS 1.2+
- ✅ **Data at Rest**: Firebase Firestore automatically encrypts all data at rest using AES-256
- ✅ **Firebase Authentication**: Passwords are salted and hashed using bcrypt

### 2. **Local Database Encryption (Hive)**

- ✅ **AES-256 Encryption**: All chat messages stored locally in Hive are encrypted
- ✅ **Secure Key Storage**: Encryption keys are stored in Flutter Secure Storage (iOS Keychain/Android KeyStore)
- ✅ **Per-User Encryption**: Each user has unique encryption keys

### 3. **API Keys & Sensitive Credentials**

- ✅ **Flutter Secure Storage**: API keys (Gemini) are stored using platform-specific secure storage
     - iOS: Keychain
     - Android: EncryptedSharedPreferences/KeyStore
- ✅ **SHA-256 Hashing**: Only hashed versions of API keys are stored in Firestore for verification

### 4. **Additional Field-Level Encryption (Optional)**

For extra sensitive data, you can use the `EncryptionService` to encrypt specific fields before saving to Firestore.

---

## Implementation Details

### Current Encryption Status

| Data Type         | Storage Location | Encryption Method          | Key Storage                   |
| ----------------- | ---------------- | -------------------------- | ----------------------------- |
| Passwords         | Firebase Auth    | bcrypt (salted hash)       | Firebase managed              |
| User Profiles     | Firestore        | AES-256 at rest (Firebase) | Google KMS                    |
| Posts/Discussions | Firestore        | AES-256 at rest (Firebase) | Google KMS                    |
| Chat Messages     | Hive (Local)     | AES-256 (Custom)           | Secure Storage                |
| API Keys (raw)    | Secure Storage   | Platform-specific          | iOS Keychain/Android KeyStore |
| API Keys (hash)   | Firestore        | SHA-256 hash               | N/A (one-way)                 |
| Images/Files      | Firebase Storage | AES-256 at rest            | Google KMS                    |
| Data in Transit   | All connections  | TLS 1.2+ (HTTPS)           | N/A                           |

---

## How to Use Field-Level Encryption (For Developers)

If you want to encrypt specific sensitive fields before saving to Firestore:

### 1. Initialize Encryption Service

```dart
import 'package:developer_community_app/services/encryption_service.dart';

final encryptionService = EncryptionService();
// Already initialized in main.dart automatically
```

### 2. Encrypt Fields Before Saving

```dart
// Example: Encrypting sensitive user data
Map<String, dynamic> userData = {
  'username': 'JohnDoe',
  'email': 'john@example.com',
  'bio': 'My private bio',
  'phoneNumber': '+1234567890', // Sensitive!
};

// Encrypt specific sensitive fields
final encryptedData = encryptionService.encryptFields(
  userData,
  ['phoneNumber', 'bio'], // Fields to encrypt
);

// Save to Firestore
await FirebaseFirestore.instance
    .collection('User')
    .doc(userId)
    .set(encryptedData);
```

### 3. Decrypt Fields When Reading

```dart
// Read from Firestore
final doc = await FirebaseFirestore.instance
    .collection('User')
    .doc(userId)
    .get();

// Decrypt sensitive fields
final decryptedData = encryptionService.decryptFields(
  doc.data() ?? {},
  ['phoneNumber', 'bio'],
);

// Use decrypted data
print('Bio: ${decryptedData['bio']}');
```

### 4. Simple Encrypt/Decrypt

```dart
// Encrypt a single value
String encryptedBio = encryptionService.encryptString('My secret bio');

// Decrypt a single value
String originalBio = encryptionService.decryptString(encryptedBio);
```

---

## Encryption Keys Management

### Where Are Keys Stored?

1. **Hive Encryption Key**
      - Platform: iOS Keychain / Android EncryptedSharedPreferences
      - Access: Only the app can access
      - Lifecycle: Persists across app sessions, deleted on uninstall

2. **Firestore Field Encryption Key**
      - Platform: iOS Keychain / Android KeyStore
      - Access: Only the app can access
      - Lifecycle: Persists across app sessions

3. **Firebase Encryption Keys**
      - Managed by Google Cloud KMS (Key Management Service)
      - Automatically rotated
      - Enterprise-grade security

### Key Rotation

- Firebase automatically rotates encryption keys
- Local encryption keys are generated once per installation
- To regenerate keys: Clear app data or reinstall app (⚠️ will lose local encrypted data)

---

## Security Best Practices

### ✅ What We Do

- ✅ Use industry-standard AES-256 encryption
- ✅ Store encryption keys in platform secure storage
- ✅ Encrypt data in transit with TLS 1.2+
- ✅ Use bcrypt for password hashing
- ✅ Never log sensitive data
- ✅ Implement Firebase Security Rules
- ✅ Regular security audits

### ⚠️ Important Notes

- Encryption protects data "at rest" and "in transit"
- If you lose encryption keys (app data cleared), encrypted local data is unrecoverable
- Firestore data is always recoverable (Firebase manages keys)
- Never share API keys or commit them to version control

### 🔒 User Responsibilities

- Use strong passwords (8+ characters, mixed case, numbers, symbols)
- Enable device lock (PIN/fingerprint/face unlock)
- Keep your device OS updated
- Don't root/jailbreak your device (weakens secure storage)

---

## Compliance

### GDPR Compliance

- ✅ Encryption at rest and in transit
- ✅ Data minimization
- ✅ User data export capability
- ✅ Right to deletion
- ✅ Transparent privacy policy

### Data Breach Protection

- Multiple encryption layers reduce breach impact
- Even if database is compromised, data is encrypted
- Local data encrypted with device-specific keys
- API keys hashed, not stored in plaintext

---

## Troubleshooting

### Issue: "EncryptionService not initialized" error

**Solution**: The app should auto-initialize encryption in `main.dart`. If you see this error:

```dart
await EncryptionService().initialize();
```

### Issue: Cannot decrypt old data after app reinstall

**Cause**: Encryption keys are stored locally and deleted on uninstall.
**Solution**: Cloud data (Firestore) is always accessible. Local Hive data is unrecoverable.

### Issue: Chat history lost

**Cause**: Chat messages are encrypted locally with keys in secure storage.
**Solution**: This is by design for privacy. Chat history is device-specific.

---

## For Developers: Adding More Encrypted Fields

To encrypt additional fields in your Firestore documents:

1. Identify sensitive fields (PII, financial data, health info, etc.)
2. Use `encryptFields()` before saving
3. Use `decryptFields()` after reading
4. Update this documentation

Example fields that SHOULD be encrypted:

- Phone numbers
- Physical addresses
- Payment information
- Social security numbers
- Health records
- Private messages (if stored in Firestore)

Example fields that DON'T need encryption:

- Public usernames
- Public profile pictures
- Post titles and content (meant to be public)
- Timestamps
- View counts, likes

---

## Performance Considerations

- ✅ Encryption/decryption is fast (< 1ms for typical strings)
- ✅ No noticeable impact on app performance
- ✅ Hive encryption adds minimal overhead
- ⚠️ Encrypting large text fields (> 10KB) may add ~5-10ms

---

## Contact Security Team

For security concerns or vulnerability reports:

- Email: vansh.panchal7@proton.me
- Subject Line: [SECURITY] Brief description
- Include: Steps to reproduce, potential impact

**Do not publicly disclose security vulnerabilities.**

---

**Last Updated**: February 16, 2026  
**Encryption Standard**: AES-256, TLS 1.2+  
**Compliance**: GDPR, CCPA compatible
