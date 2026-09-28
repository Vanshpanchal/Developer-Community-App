import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api_key_manager.dart';
import '../messagemodel.dart';
import '../utils/app_logger.dart';
import '../utils/avatar_manager.dart';
import 'block_service.dart';
import 'firebase_cache_service.dart';
import 'notification_service.dart';
import 'user_cache_service.dart';

/// Sign-in bootstrap and sign-out cleanup shared by every screen.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  final _auth = FirebaseAuth.instance;

  /// Makes sure `User/{uid}` exists and holds no private fields.
  ///
  /// Signup writes the profile right after creating the auth user; if that
  /// write failed the user would otherwise be signed in with no profile.
  /// Older profiles also stored `Email`, which every user can read, so it is
  /// removed here (Firebase Auth already holds the address).
  Future<void> ensureProfile(User user) async {
    final firestore = FirebaseFirestore.instance;
    final ref = firestore.collection('User').doc(user.uid);

    // Fast path: a plain read (served from cache when offline) settles the
    // common case without a network round-trip transaction.
    final current = await ref.get();
    if (current.exists) {
      if (current.data()?.containsKey('Email') ?? false) {
        await ref.update({'Email': FieldValue.delete()});
      }
      return;
    }

    // Transaction so a concurrent signup write is never overwritten.
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final email = user.email ?? '';
        tx.set(ref, {
          'Username': (user.displayName?.trim().isNotEmpty ?? false)
              ? user.displayName!.trim()
              : (email.contains('@') ? email.split('@').first : 'Developer'),
          'Uid': user.uid,
          'profilePicture': AvatarManager.avatars.first,
          'XP': 100,
          'Saved': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (snap.data()?.containsKey('Email') ?? false) {
        tx.update(ref, {'Email': FieldValue.delete()});
      }
    });
  }

  /// Stores this device's FCM token under the owner-only private doc.
  Future<void> registerFcmToken(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      await _tokensRef(user.uid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.warning('Failed to store FCM token: $e');
    }
  }

  /// Signs out and removes everything the session left on the device.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;

    // Stop pushes for this account on this device.
    if (uid != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _tokensRef(uid).set({
            'fcmTokens': FieldValue.arrayRemove([token]),
            'fcmToken': FieldValue.delete(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        AppLogger.warning('Failed to remove FCM token on sign-out: $e');
      }
    }

    await _auth.signOut();
    await clearLocalSession();
  }

  /// Removes everything the session left on this device. Used by sign-out
  /// and by account deletion (after the auth user is already gone).
  Future<void> clearLocalSession() async {
    BlockService.instance.stop();
    NotificationService.instance.stop();
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      AppLogger.warning('Failed to delete FCM token: $e');
    }

    // Local caches, the user's Gemini key and chat history.
    try {
      await FirebaseCacheService().clearAllCache();
      await ApiKeyManager.instance.clearKey();
      if (Hive.isBoxOpen('chat_messages')) {
        await Hive.box<Message>('chat_messages').clear();
      }
      await GetStorage().erase();
      UserCacheService.instance.clearAll();
    } catch (e) {
      AppLogger.warning('Error clearing local data: $e');
    }

    // Firestore's on-disk cache still holds the previous session's
    // documents. clearPersistence requires a terminated instance; the
    // plugin creates a fresh instance on next use.
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      AppLogger.warning('Failed to clear Firestore persistence: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _tokensRef(String uid) =>
      FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .collection('private')
          .doc('tokens');
}
