import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/poll_model.dart';
import 'gamification_service.dart';
import '../models/gamification_models.dart';

/// Service to manage polls
class PollService {
  PollService._internal();
  static final PollService _instance = PollService._internal();
  factory PollService() => _instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _gamification = GamificationService();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Create a new poll attached to a discussion or post
  Future<Poll?> createPoll({
    required PollCreationData pollData,
    required String parentId,
    required String parentCollection, // 'Discussions' or 'Explore'
  }) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    if (!pollData.isValid) {
      debugPrint('Invalid poll data');
      return null;
    }

    try {
      final poll = pollData.toPoll(userId);

      // Add poll to the parent document
      await _firestore.collection(parentCollection).doc(parentId).update({
        'poll': poll.toMap(),
        'hasPoll': true,
      });

      // Award XP for creating poll
      await _gamification.awardXp(XpAction.pollCreated);
      await _gamification.incrementCounter('pollsCreated');

      return poll;
    } catch (e) {
      debugPrint('Error creating poll: $e');
      return null;
    }
  }

  /// Create a standalone poll in the Polls collection
  Future<Poll?> createStandalonePoll(PollCreationData pollData) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    if (!pollData.isValid) {
      debugPrint('Invalid poll data');
      return null;
    }

    try {
      final poll = pollData.toPoll(userId);
      final docRef = _firestore.collection('Polls').doc(poll.id);

      await docRef.set({
        ...poll.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Award XP
      await _gamification.awardXp(XpAction.pollCreated);
      await _gamification.incrementCounter('pollsCreated');

      return poll;
    } catch (e) {
      debugPrint('Error creating standalone poll: $e');
      return null;
    }
  }

  /// Vote on a poll
  Future<bool> vote({
    required String pollId,
    required String optionId,
    required String parentId,
    required String parentCollection,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final docRef = _firestore.collection(parentCollection).doc(parentId);

      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        final pollData = doc.data()?['poll'] as Map<String, dynamic>?;

        if (pollData == null) return false;

        final poll = Poll.fromMap(pollData);

        // Check if poll is expired
        if (poll.isExpired) return false;

        // Check if already voted (for single vote polls)
        if (!poll.allowMultipleVotes && poll.hasUserVoted(userId)) {
          return false;
        }

        // Update the options
        final updatedOptions = poll.options.map((opt) {
          if (opt.id == optionId) {
            if (opt.voterIds.contains(userId)) {
              // Already voted for this option
              return opt;
            }
            return opt.copyWith(
              voterIds: [...opt.voterIds, userId],
            );
          }
          return opt;
        }).toList();

        final updatedPoll = poll.copyWith(options: updatedOptions);

        transaction.update(docRef, {
          'poll': updatedPoll.toMap(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error voting on poll: $e');
      return false;
    } finally {
      // Award XP for voting (outside transaction)
      await _gamification.awardXp(XpAction.pollVote);
      await _gamification.incrementCounter('pollsVoted');
    }
  }

  /// Remove vote from a poll option
  Future<bool> removeVote({
    required String pollId,
    required String optionId,
    required String parentId,
    required String parentCollection,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final docRef = _firestore.collection(parentCollection).doc(parentId);

      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        final pollData = doc.data()?['poll'] as Map<String, dynamic>?;

        if (pollData == null) return false;

        final poll = Poll.fromMap(pollData);

        // Update the options
        final updatedOptions = poll.options.map((opt) {
          if (opt.id == optionId) {
            return opt.copyWith(
              voterIds: opt.voterIds.where((id) => id != userId).toList(),
            );
          }
          return opt;
        }).toList();

        final updatedPoll = poll.copyWith(options: updatedOptions);

        transaction.update(docRef, {
          'poll': updatedPoll.toMap(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error removing vote: $e');
      return false;
    }
  }

  /// Get poll from a document
  Future<Poll?> getPoll({
    required String parentId,
    required String parentCollection,
  }) async {
    try {
      final doc =
          await _firestore.collection(parentCollection).doc(parentId).get();
      final pollData = doc.data()?['poll'] as Map<String, dynamic>?;

      if (pollData == null) return null;
      return Poll.fromMap(pollData);
    } catch (e) {
      debugPrint('Error getting poll: $e');
      return null;
    }
  }

  /// Delete a poll
  Future<bool> deletePoll({
    required String parentId,
    required String parentCollection,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final docRef = _firestore.collection(parentCollection).doc(parentId);
      final doc = await docRef.get();
      final pollData = doc.data()?['poll'] as Map<String, dynamic>?;

      if (pollData == null) return false;

      final poll = Poll.fromMap(pollData);

      // Only creator can delete
      if (poll.creatorId != userId) return false;

      await docRef.update({
        'poll': FieldValue.delete(),
        'hasPoll': false,
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting poll: $e');
      return false;
    }
  }

  /// Stream polls for a collection
  Stream<List<Poll>> streamPolls(String collection) {
    return _firestore
        .collection(collection)
        .where('hasPoll', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final pollData = doc.data()['poll'] as Map<String, dynamic>?;
            if (pollData == null) return null;
            return Poll.fromMap(pollData);
          })
          .whereType<Poll>()
          .toList();
    });
  }
}
