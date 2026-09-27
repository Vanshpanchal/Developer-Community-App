import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gamification_models.dart';
import 'gamification_service.dart';
import '../utils/app_logger.dart';

/// Abstract repository interface for Discussions domain
abstract class IDiscussionRepository {
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDiscussion(String docId);
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(String docId);
  Future<String?> addReply({
    required String discussionId,
    required String replyText,
    required String username,
    required String profilePicture,
    required double qualityScore,
    required String contentStatus,
    required bool shouldDeprioritize,
    required List<String> moderationFlags,
    required String moderationSource,
  });
  Future<void> adjustUserXp({
    required String uid,
    required int points,
    required String action,
    required String description,
  });
}

/// Production implementation of Discussion repository
class DiscussionRepository implements IDiscussionRepository {
  DiscussionRepository._internal();
  static final DiscussionRepository _instance = DiscussionRepository._internal();
  factory DiscussionRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamification = GamificationService();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDiscussion(String docId) {
    return _firestore.collection('Discussions').doc(docId).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(String docId) {
    return _firestore
        .collection('Discussions')
        .doc(docId)
        .collection('Replies')
        .orderBy('timestamp')
        .snapshots();
  }

  @override
  Future<String?> addReply({
    required String discussionId,
    required String replyText,
    required String username,
    required String profilePicture,
    required double qualityScore,
    required String contentStatus,
    required bool shouldDeprioritize,
    required List<String> moderationFlags,
    required String moderationSource,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be authenticated to reply');
    }

    try {
      final replyDocRef = _firestore
          .collection('Discussions')
          .doc(discussionId)
          .collection('Replies')
          .doc();

      await replyDocRef.set({
        'replyId': replyDocRef.id,
        'reply': replyText,
        'user_name': username,
        'profilePicture': profilePicture,
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'code': '',
        'accepted': false,
        'likes': [],
        'qualityScore': qualityScore,
        'contentStatus': contentStatus,
        'deprioritizeInFeed': shouldDeprioritize,
        'moderationFlags': moderationFlags,
        'moderationSource': moderationSource,
      });

      // Award XP for posting reply
      await _gamification.awardXp(XpAction.postReply);
      await _gamification.incrementCounter('repliesCount');
      await _gamification.recordActivity();

      return replyDocRef.id;
    } catch (e, st) {
      AppLogger.error('Failed to post reply: $e', e, st, 'DiscussionRepository');
      rethrow;
    }
  }

  @override
  Future<void> adjustUserXp({
    required String uid,
    required int points,
    required String action,
    required String description,
  }) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'XP': FieldValue.increment(points),
        'lastXpUpdate': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('User')
          .doc(uid)
          .collection('xp_history')
          .add({
        'action': action,
        'xp': points,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
      });
    } catch (e, st) {
      AppLogger.error('Failed to adjust user XP: $e', e, st, 'DiscussionRepository');
    }
  }
}
