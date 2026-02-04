import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/gamification_models.dart';

/// Service to manage all gamification features
class GamificationService {
  GamificationService._internal();
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ==================== BADGES ====================

  /// All available badges in the system
  static final List<Badge> allBadges = [
    // Posts badges
    const Badge(
      id: 'first_post',
      name: 'First Steps',
      description: 'Create your first post',
      icon: '🎉',
      category: BadgeCategory.posts,
      rarity: BadgeRarity.common,
      xpReward: 50,
      criteria: {'postsCount': 1},
    ),
    const Badge(
      id: 'post_5',
      name: 'Content Creator',
      description: 'Create 5 posts',
      icon: '✍️',
      category: BadgeCategory.posts,
      rarity: BadgeRarity.uncommon,
      xpReward: 100,
      criteria: {'postsCount': 5},
    ),
    const Badge(
      id: 'post_25',
      name: 'Prolific Writer',
      description: 'Create 25 posts',
      icon: '📚',
      category: BadgeCategory.posts,
      rarity: BadgeRarity.rare,
      xpReward: 250,
      criteria: {'postsCount': 25},
    ),
    const Badge(
      id: 'post_100',
      name: 'Publishing Legend',
      description: 'Create 100 posts',
      icon: '🏆',
      category: BadgeCategory.posts,
      rarity: BadgeRarity.legendary,
      xpReward: 500,
      criteria: {'postsCount': 100},
    ),

    // Discussion badges
    const Badge(
      id: 'first_discussion',
      name: 'Conversation Starter',
      description: 'Start your first discussion',
      icon: '💬',
      category: BadgeCategory.discussions,
      rarity: BadgeRarity.common,
      xpReward: 50,
      criteria: {'discussionsCount': 1},
    ),
    const Badge(
      id: 'discussion_10',
      name: 'Discussion Leader',
      description: 'Start 10 discussions',
      icon: '🎤',
      category: BadgeCategory.discussions,
      rarity: BadgeRarity.uncommon,
      xpReward: 150,
      criteria: {'discussionsCount': 10},
    ),
    const Badge(
      id: 'reply_50',
      name: 'Active Contributor',
      description: 'Post 50 replies',
      icon: '💡',
      category: BadgeCategory.discussions,
      rarity: BadgeRarity.rare,
      xpReward: 200,
      criteria: {'repliesCount': 50},
    ),

    // Engagement badges
    const Badge(
      id: 'likes_10',
      name: 'Appreciated',
      description: 'Receive 10 likes',
      icon: '👍',
      category: BadgeCategory.engagement,
      rarity: BadgeRarity.common,
      xpReward: 50,
      criteria: {'likesReceived': 10},
    ),
    const Badge(
      id: 'likes_100',
      name: 'Popular Voice',
      description: 'Receive 100 likes',
      icon: '🌟',
      category: BadgeCategory.engagement,
      rarity: BadgeRarity.rare,
      xpReward: 200,
      criteria: {'likesReceived': 100},
    ),
    const Badge(
      id: 'likes_500',
      name: 'Community Favorite',
      description: 'Receive 500 likes',
      icon: '💎',
      category: BadgeCategory.engagement,
      rarity: BadgeRarity.legendary,
      xpReward: 500,
      criteria: {'likesReceived': 500},
    ),
    const Badge(
      id: 'supporter_50',
      name: 'Supporter',
      description: 'Give 50 likes to others',
      icon: '🤗',
      category: BadgeCategory.engagement,
      rarity: BadgeRarity.uncommon,
      xpReward: 100,
      criteria: {'likesGiven': 50},
    ),

    // Streak badges
    const Badge(
      id: 'streak_7',
      name: 'Week Warrior',
      description: '7-day activity streak',
      icon: '🔥',
      category: BadgeCategory.streak,
      rarity: BadgeRarity.uncommon,
      xpReward: 150,
      criteria: {'streak': 7},
    ),
    const Badge(
      id: 'streak_30',
      name: 'Month Master',
      description: '30-day activity streak',
      icon: '⚡',
      category: BadgeCategory.streak,
      rarity: BadgeRarity.rare,
      xpReward: 400,
      criteria: {'streak': 30},
    ),
    const Badge(
      id: 'streak_100',
      name: 'Unstoppable',
      description: '100-day activity streak',
      icon: '🏅',
      category: BadgeCategory.streak,
      rarity: BadgeRarity.legendary,
      xpReward: 1000,
      criteria: {'streak': 100},
    ),

    // Milestone badges
    const Badge(
      id: 'xp_1000',
      name: 'Rising Star',
      description: 'Reach 1,000 XP',
      icon: '⭐',
      category: BadgeCategory.milestone,
      rarity: BadgeRarity.uncommon,
      xpReward: 100,
      criteria: {'totalXp': 1000},
    ),
    const Badge(
      id: 'xp_5000',
      name: 'Expert Developer',
      description: 'Reach 5,000 XP',
      icon: '🎯',
      category: BadgeCategory.milestone,
      rarity: BadgeRarity.rare,
      xpReward: 250,
      criteria: {'totalXp': 5000},
    ),
    const Badge(
      id: 'xp_10000',
      name: 'Master Coder',
      description: 'Reach 10,000 XP',
      icon: '👑',
      category: BadgeCategory.milestone,
      rarity: BadgeRarity.epic,
      xpReward: 500,
      criteria: {'totalXp': 10000},
    ),

    // Special badges
    const Badge(
      id: 'poll_creator',
      name: 'Poll Master',
      description: 'Create 5 polls',
      icon: '📊',
      category: BadgeCategory.special,
      rarity: BadgeRarity.uncommon,
      xpReward: 100,
      criteria: {'pollsCreated': 5},
    ),
    const Badge(
      id: 'early_adopter',
      name: 'Early Adopter',
      description: 'Joined during beta',
      icon: '🚀',
      category: BadgeCategory.special,
      rarity: BadgeRarity.epic,
      xpReward: 200,
      criteria: {'special': 'early_adopter'},
    ),
  ];

  /// Get badge by ID
  static Badge? getBadgeById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==================== CHALLENGES ====================

  /// Generate daily challenges
  List<Challenge> generateDailyChallenges() {
    final today = DateTime.now();
    final expiry = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return [
      Challenge(
        id: 'daily_post_${today.day}',
        title: 'Daily Share',
        description: 'Create at least 1 post today',
        type: ChallengeType.daily,
        xpReward: 30,
        requirements: {'postsToday': 1},
        expiresAt: expiry,
      ),
      Challenge(
        id: 'daily_engage_${today.day}',
        title: 'Community Spirit',
        description: 'Like 3 posts and reply to 1 discussion',
        type: ChallengeType.daily,
        xpReward: 40,
        requirements: {'likesToday': 3, 'repliesToday': 1},
        expiresAt: expiry,
      ),
      Challenge(
        id: 'daily_explore_${today.day}',
        title: 'Explorer',
        description: 'View 5 different posts',
        type: ChallengeType.daily,
        xpReward: 20,
        requirements: {'viewsToday': 5},
        expiresAt: expiry,
      ),
    ];
  }

  /// Generate weekly challenges
  List<Challenge> generateWeeklyChallenges() {
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    final expiry =
        DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
    final weekNum = (now.day / 7).ceil();

    return [
      Challenge(
        id: 'weekly_posts_$weekNum',
        title: 'Weekly Writer',
        description: 'Create 5 posts this week',
        type: ChallengeType.weekly,
        xpReward: 150,
        requirements: {'postsThisWeek': 5},
        expiresAt: expiry,
      ),
      Challenge(
        id: 'weekly_helper_$weekNum',
        title: 'Community Helper',
        description: 'Reply to 10 discussions this week',
        type: ChallengeType.weekly,
        xpReward: 200,
        requirements: {'repliesThisWeek': 10},
        expiresAt: expiry,
      ),
      Challenge(
        id: 'weekly_streak_$weekNum',
        title: 'Consistent Contributor',
        description: 'Be active for 5 consecutive days',
        type: ChallengeType.weekly,
        xpReward: 175,
        requirements: {'streakDays': 5},
        expiresAt: expiry,
      ),
    ];
  }

  // ==================== XP MANAGEMENT ====================

  /// Award XP to user
  Future<void> awardXp(XpAction action,
      {int? customXp, String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return;

    final xpToAdd = customXp ?? action.defaultXp;
    if (xpToAdd <= 0) return;

    try {
      final userRef = _firestore.collection('User').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentXp =
            int.tryParse(userDoc.data()?['XP']?.toString() ?? '0') ?? 0;
        final newXp = currentXp + xpToAdd;

        transaction.update(userRef, {
          'XP': newXp.toString(),
          'lastXpUpdate': FieldValue.serverTimestamp(),
        });

        // Log XP history
        transaction.set(
          userRef.collection('xp_history').doc(),
          {
            'action': action.name,
            'xp': xpToAdd,
            'timestamp': FieldValue.serverTimestamp(),
            'description': action.description,
          },
        );
      });

      // Check for level up and badges
      await _checkBadgesAndMilestones(userId);
    } catch (e) {
      debugPrint('Error awarding XP: $e');
    }
  }

  // ==================== STREAK MANAGEMENT ====================

  /// Record daily activity and update streak
  Future<DailyStreak> recordActivity({String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return DailyStreak.empty();

    try {
      final userRef = _firestore.collection('User').doc(userId);
      final streakRef = userRef.collection('gamification').doc('streak');

      return await _firestore.runTransaction((transaction) async {
        final streakDoc = await transaction.get(streakRef);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        DailyStreak currentStreak;
        if (streakDoc.exists) {
          currentStreak = DailyStreak.fromMap(streakDoc.data()!);
        } else {
          currentStreak = DailyStreak.empty();
        }

        // Check if already active today
        if (currentStreak.isActiveToday) {
          return currentStreak;
        }

        int newStreak = 1;
        int longestStreak = currentStreak.longestStreak;

        if (currentStreak.lastActivityDate != null) {
          final lastDate = currentStreak.lastActivityDate!;
          final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
          final diff = today.difference(lastDay).inDays;

          if (diff == 1) {
            // Consecutive day - increase streak
            newStreak = currentStreak.currentStreak + 1;
          } else if (diff == 0) {
            // Same day - keep streak
            newStreak = currentStreak.currentStreak;
          }
          // If diff > 1, streak resets to 1
        }

        if (newStreak > longestStreak) {
          longestStreak = newStreak;
        }

        final updatedStreak = DailyStreak(
          currentStreak: newStreak,
          longestStreak: longestStreak,
          lastActivityDate: now,
          activityHistory: [...currentStreak.activityHistory.take(30), now],
        );

        transaction.set(streakRef, updatedStreak.toMap());

        // Award streak XP
        if (newStreak > currentStreak.currentStreak) {
          // New day in streak
          int streakBonus = 10; // Base daily XP
          if (newStreak % 7 == 0) streakBonus += 50; // Weekly bonus
          if (newStreak % 30 == 0) streakBonus += 200; // Monthly bonus

          transaction.update(userRef, {
            'XP': FieldValue.increment(streakBonus),
          });
        }

        return updatedStreak;
      });
    } catch (e) {
      debugPrint('Error recording activity: $e');
      return DailyStreak.empty();
    }
  }

  /// Get current streak
  Future<DailyStreak> getStreak({String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return DailyStreak.empty();

    try {
      final streakDoc = await _firestore
          .collection('User')
          .doc(userId)
          .collection('gamification')
          .doc('streak')
          .get();

      if (streakDoc.exists) {
        return DailyStreak.fromMap(streakDoc.data()!);
      }
    } catch (e) {
      debugPrint('Error getting streak: $e');
    }
    return DailyStreak.empty();
  }

  // ==================== BADGES MANAGEMENT ====================

  /// Get user's earned badges
  Future<List<EarnedBadge>> getUserBadges({String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return [];

    try {
      final userDoc = await _firestore.collection('User').doc(userId).get();
      final badgesData = userDoc.data()?['badges'] as List<dynamic>?;
      if (badgesData == null) return [];

      return badgesData
          .map((b) => EarnedBadge.fromMap(Map<String, dynamic>.from(b)))
          .toList();
    } catch (e) {
      debugPrint('Error getting badges: $e');
      return [];
    }
  }

  /// Award badge to user
  Future<bool> awardBadge(String badgeId, {String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return false;

    final badge = getBadgeById(badgeId);
    if (badge == null) return false;

    try {
      final userRef = _firestore.collection('User').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final existingBadges = (userDoc.data()?['badges'] as List<dynamic>?)
                ?.map((b) => EarnedBadge.fromMap(Map<String, dynamic>.from(b)))
                .toList() ??
            [];

        // Check if already has badge
        if (existingBadges.any((b) => b.badgeId == badgeId)) {
          return false;
        }

        final newBadge = EarnedBadge(
          badgeId: badgeId,
          earnedAt: DateTime.now(),
        );

        transaction.update(userRef, {
          'badges': FieldValue.arrayUnion([newBadge.toMap()]),
          'XP': FieldValue.increment(badge.xpReward),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error awarding badge: $e');
      return false;
    }
  }

  /// Check and award badges based on current stats
  Future<void> _checkBadgesAndMilestones(String userId) async {
    try {
      final stats = await getGamificationStats(targetUserId: userId);

      for (final badge in allBadges) {
        // Skip if already earned
        if (stats.badges.any((b) => b.badgeId == badge.id)) continue;

        bool earned = false;
        final criteria = badge.criteria;

        if (criteria.containsKey('postsCount')) {
          earned = stats.postsCount >= (criteria['postsCount'] as int);
        } else if (criteria.containsKey('discussionsCount')) {
          earned =
              stats.discussionsCount >= (criteria['discussionsCount'] as int);
        } else if (criteria.containsKey('repliesCount')) {
          earned = stats.repliesCount >= (criteria['repliesCount'] as int);
        } else if (criteria.containsKey('likesReceived')) {
          earned = stats.likesReceived >= (criteria['likesReceived'] as int);
        } else if (criteria.containsKey('likesGiven')) {
          earned = stats.likesGiven >= (criteria['likesGiven'] as int);
        } else if (criteria.containsKey('streak')) {
          earned = stats.streak.currentStreak >= (criteria['streak'] as int);
        } else if (criteria.containsKey('totalXp')) {
          earned = stats.totalXp >= (criteria['totalXp'] as int);
        } else if (criteria.containsKey('pollsCreated')) {
          earned = stats.pollsCreated >= (criteria['pollsCreated'] as int);
        }

        if (earned) {
          await awardBadge(badge.id, targetUserId: userId);
        }
      }
    } catch (e) {
      debugPrint('Error checking badges: $e');
    }
  }

  // ==================== LEADERBOARD ====================

  /// Get leaderboard entries
  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 50}) async {
    try {
      // Query users sorted by XP
      final querySnapshot = await _firestore
          .collection('User')
          .orderBy('XP', descending: true)
          .limit(limit)
          .get();

      final entries = <LeaderboardEntry>[];
      int rank = 1;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        data['uid'] = doc.id;
        entries.add(LeaderboardEntry.fromMap(data, rank));
        rank++;
      }

      return entries;
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank
  Future<int> getUserRank({String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return -1;

    try {
      final userDoc = await _firestore.collection('User').doc(userId).get();
      final userXp =
          int.tryParse(userDoc.data()?['XP']?.toString() ?? '0') ?? 0;

      final higherRanked = await _firestore
          .collection('User')
          .where('XP', isGreaterThan: userXp)
          .count()
          .get();

      return (higherRanked.count ?? 0) + 1;
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return -1;
    }
  }

  // ==================== STATS ====================

  /// Get comprehensive gamification stats
  Future<GamificationStats> getGamificationStats({String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return GamificationStats.empty();

    try {
      // Fetch user document
      final userDoc = await _firestore.collection('User').doc(userId).get();
      final userData = userDoc.data() ?? {};

      final totalXp = int.tryParse(userData['XP']?.toString() ?? '0') ?? 0;
      final level = UserLevel.fromXp(totalXp);

      // Fetch streak
      final streak = await getStreak(targetUserId: userId);

      // Fetch badges
      final badges = await getUserBadges(targetUserId: userId);

      // Fetch counts
      final postsSnap = await _firestore
          .collection('Explore')
          .where('Uid', isEqualTo: userId)
          .count()
          .get();

      final discussionsSnap = await _firestore
          .collection('Discussions')
          .where('Uid', isEqualTo: userId)
          .count()
          .get();

      // Get likes received (sum from all user's posts)
      int likesReceived = 0;
      final userPosts = await _firestore
          .collection('Explore')
          .where('Uid', isEqualTo: userId)
          .get();
      for (final post in userPosts.docs) {
        likesReceived += (post.data()['likescount'] as int?) ?? 0;
      }

      final likesGiven = userData['likesGiven'] as int? ?? 0;
      final pollsCreated = userData['pollsCreated'] as int? ?? 0;
      final pollsVoted = userData['pollsVoted'] as int? ?? 0;
      final repliesCount = userData['repliesCount'] as int? ?? 0;

      return GamificationStats(
        totalXp: totalXp,
        level: level,
        streak: streak,
        badges: badges,
        activeChallenges: [], // TODO: Implement challenge tracking
        postsCount: postsSnap.count ?? 0,
        discussionsCount: discussionsSnap.count ?? 0,
        repliesCount: repliesCount,
        likesReceived: likesReceived,
        likesGiven: likesGiven,
        pollsCreated: pollsCreated,
        pollsVoted: pollsVoted,
      );
    } catch (e) {
      debugPrint('Error getting gamification stats: $e');
      return GamificationStats.empty();
    }
  }

  /// Increment counter for various actions
  Future<void> incrementCounter(String field,
      {int value = 1, String? targetUserId}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return;

    try {
      await _firestore.collection('User').doc(userId).update({
        field: FieldValue.increment(value),
      });
    } catch (e) {
      debugPrint('Error incrementing counter: $e');
    }
  }
}
