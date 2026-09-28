import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_logger.dart';
import 'session_service.dart';

/// Deletes content and the account itself, entirely from the client (the
/// project has no Cloud Functions). Every write here is one the Firestore
/// rules already allow the owner to make.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Deletes a post the current user owns.
  Future<void> deletePost(String postId) =>
      _db.collection('Explore').doc(postId).delete();

  /// Deletes a discussion the current user owns, including every reply and
  /// nested reply in it (the rules let a discussion owner remove those).
  Future<void> deleteDiscussion(String discussionId) async {
    final discussionRef = _db.collection('Discussions').doc(discussionId);
    final replies = await discussionRef.collection('Replies').get();
    for (final reply in replies.docs) {
      final subReplies = await reply.reference.collection('SubReplies').get();
      await _deleteAll(subReplies.docs.map((d) => d.reference));
    }
    await _deleteAll(replies.docs.map((d) => d.reference));
    await discussionRef.delete();
  }

  /// Permanently deletes the signed-in user's account and their data.
  ///
  /// [password] re-authenticates first, since Firebase requires a recent
  /// sign-in to delete an account. Throws [FirebaseAuthException] on a wrong
  /// password.
  Future<void> deleteAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in user');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    final uid = user.uid;

    // 1. Discussions and posts they created.
    final discussions = await _db
        .collection('Discussions')
        .where('Uid', isEqualTo: uid)
        .get();
    for (final d in discussions.docs) {
      await deleteDiscussion(d.id);
    }
    final posts =
        await _db.collection('Explore').where('Uid', isEqualTo: uid).get();
    await _deleteAll(posts.docs.map((d) => d.reference));

    // 2. Their replies and nested replies in other people's discussions.
    final subReplies = await _db
        .collectionGroup('SubReplies')
        .where('uid', isEqualTo: uid)
        .get();
    await _deleteAll(subReplies.docs.map((d) => d.reference));
    final replies =
        await _db.collectionGroup('Replies').where('uid', isEqualTo: uid).get();
    await _deleteAll(replies.docs.map((d) => d.reference));

    // 3. Their likes on remaining posts and replies.
    final likedPosts = await _db
        .collection('Explore')
        .where('likes', arrayContains: uid)
        .get();
    for (final post in likedPosts.docs) {
      await post.reference.update({
        'likes': FieldValue.arrayRemove([uid]),
        'likescount': FieldValue.increment(-1),
      });
    }
    final likedReplies = await _db
        .collectionGroup('Replies')
        .where('likes', arrayContains: uid)
        .get();
    for (final reply in likedReplies.docs) {
      await reply.reference.update({'likes': FieldValue.arrayRemove([uid])});
    }

    // 4. Challenge progress and the profile with its subcollections.
    final challenges = await _db
        .collectionGroup('UserChallenges')
        .where('userId', isEqualTo: uid)
        .get();
    await _deleteAll(challenges.docs.map((d) => d.reference));

    final userRef = _db.collection('User').doc(uid);
    for (final sub in [
      'xp_history',
      'gamification',
      'PortfolioHistory',
      'Saved',
      'private',
    ]) {
      final docs = await userRef.collection(sub).get();
      await _deleteAll(docs.docs.map((d) => d.reference));
    }
    await userRef.delete();

    // 5. The sign-in account, then everything stored on this device.
    await user.delete();
    await SessionService.instance.clearLocalSession();
    AppLogger.info('Account $uid deleted');
  }

  /// Deletes documents in batches of up to 400 writes.
  Future<void> _deleteAll(Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = _db.batch();
      for (final ref in list.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
