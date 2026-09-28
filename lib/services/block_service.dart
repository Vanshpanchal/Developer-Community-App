import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

/// The signed-in user's block list, stored in the owner-only
/// `User/{uid}/private/blocked` document as `{uids: [...]}`.
///
/// Blocking is personal: content by blocked users is hidden only for the
/// person who blocked them.
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  /// Uids the current user has blocked. Listen to rebuild filtered lists.
  final ValueNotifier<Set<String>> blockedIds = ValueNotifier(<String>{});

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .collection('private')
          .doc('blocked');

  bool isBlocked(String? uid) => uid != null && blockedIds.value.contains(uid);

  /// Starts streaming the block list for [uid]. Safe to call repeatedly.
  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _sub = _ref(uid).snapshots().listen((doc) {
      blockedIds.value = Set<String>.from(doc.data()?['uids'] ?? const []);
    }, onError: (e) => AppLogger.warning('Block list stream error: $e'));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    blockedIds.value = <String>{};
  }

  Future<void> block(String targetUid) => _update(targetUid, block: true);

  Future<void> unblock(String targetUid) => _update(targetUid, block: false);

  Future<void> _update(String targetUid, {required bool block}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || targetUid.isEmpty || targetUid == uid) return;
    // Update locally first so lists filter immediately.
    final next = {...blockedIds.value};
    block ? next.add(targetUid) : next.remove(targetUid);
    blockedIds.value = next;
    await _ref(uid).set({
      'uids': block
          ? FieldValue.arrayUnion([targetUid])
          : FieldValue.arrayRemove([targetUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
