import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import '../detail_discussion.dart';
import '../utils/app_logger.dart';
import '../utils/app_snackbar.dart';

/// Client-side push handling (audit BUG-12).
///
/// Expected message `data` for deep links:
///   `{ "discussionId": "<id>", "creatorId": "<uid>" }`
/// Messages without it only show their text.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final List<StreamSubscription> _subs = [];
  bool _started = false;

  /// Starts listening once per app run. Call after sign-in.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final messaging = FirebaseMessaging.instance;

    // Tokens rotate; keep the stored copy current.
    _subs.add(messaging.onTokenRefresh.listen(_saveToken, onError: (e) {
      AppLogger.warning('FCM token refresh error: $e');
    }));

    // Foreground: the OS does not show a notification, so show it in-app.
    _subs.add(FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      AppSnackbar.info(n.body ?? '', title: n.title ?? 'DevSphere');
    }));

    // Taps while the app is in the background.
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage));

    // Tap that launched the app from terminated state.
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openFromMessage(initial);
    } catch (e) {
      AppLogger.warning('Could not read initial message: $e');
    }
  }

  void stop() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _started = false;
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('private')
        .doc('tokens')
        .set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _openFromMessage(RemoteMessage message) {
    final discussionId = message.data['discussionId']?.toString();
    if (discussionId == null || discussionId.isEmpty) return;
    Get.to(() => detail_discussion(
          docId: discussionId,
          creatorId: message.data['creatorId']?.toString() ?? '',
        ));
  }
}
