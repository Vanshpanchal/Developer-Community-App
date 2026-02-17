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

  // ==================== CHALLENGES ====================

  /// Helper method to get user level from current user
  Future<UserLevel> _getCurrentUserLevel() async {
    if (_currentUserId == null) return UserLevel.beginner;

    try {
      final userDoc =
          await _firestore.collection('User').doc(_currentUserId).get();
      final totalXp =
          int.tryParse(userDoc.data()?['XP']?.toString() ?? '0') ?? 0;
      return UserLevel.fromXp(totalXp);
    } catch (e) {
      debugPrint('Error getting user level: $e');
      return UserLevel.beginner;
    }
  }

  /// Generate level-appropriate daily challenges
  static List<Challenge> _generateDailyChallengesForLevel(UserLevel level) {
    switch (level) {
      case UserLevel.beginner:
        return [
          const Challenge(
              id: 'd_post',
              title: 'First Steps',
              description: 'Create 1 post',
              type: ChallengeType.daily,
              xpReward: 30,
              requirements: {'postsToday': 1}),
          const Challenge(
              id: 'd_like',
              title: 'Spread Love',
              description: 'Like 2 posts',
              type: ChallengeType.daily,
              xpReward: 20,
              requirements: {'likesToday': 2}),
          const Challenge(
              id: 'd_reply',
              title: 'Join Conversation',
              description: 'Reply to 1 post',
              type: ChallengeType.daily,
              xpReward: 25,
              requirements: {'repliesToday': 1}),
          const Challenge(
              id: 'd_view',
              title: 'Explorer',
              description: 'View 5 posts',
              type: ChallengeType.daily,
              xpReward: 15,
              requirements: {'viewsToday': 5}),
          const Challenge(
              id: 'd_poll',
              title: 'Curious Mind',
              description: 'Vote in a poll',
              type: ChallengeType.daily,
              xpReward: 20,
              requirements: {'pollsVotedToday': 1}),
        ];

      case UserLevel.intermediate:
        return [
          const Challenge(
              id: 'd_post',
              title: 'Daily Share',
              description: 'Create 2 posts',
              type: ChallengeType.daily,
              xpReward: 50,
              requirements: {'postsToday': 2}),
          const Challenge(
              id: 'd_like',
              title: 'Community Support',
              description: 'Like 5 posts',
              type: ChallengeType.daily,
              xpReward: 35,
              requirements: {'likesToday': 5}),
          const Challenge(
              id: 'd_reply',
              title: 'Active Helper',
              description: 'Reply to 2 posts',
              type: ChallengeType.daily,
              xpReward: 45,
              requirements: {'repliesToday': 2}),
          const Challenge(
              id: 'd_view',
              title: 'Knowledge Seeker',
              description: 'View 10 posts',
              type: ChallengeType.daily,
              xpReward: 25,
              requirements: {'viewsToday': 10}),
          const Challenge(
              id: 'd_poll',
              title: 'Opinion Matters',
              description: 'Vote in 2 polls',
              type: ChallengeType.daily,
              xpReward: 35,
              requirements: {'pollsVotedToday': 2}),
        ];

      case UserLevel.advanced:
        return [
          const Challenge(
              id: 'd_post',
              title: 'Content Creator',
              description: 'Create 3 quality posts',
              type: ChallengeType.daily,
              xpReward: 70,
              requirements: {'postsToday': 3}),
          const Challenge(
              id: 'd_like',
              title: 'Influencer',
              description: 'Like 8 posts',
              type: ChallengeType.daily,
              xpReward: 50,
              requirements: {'likesToday': 8}),
          const Challenge(
              id: 'd_reply',
              title: 'Mentor',
              description: 'Reply to 3 discussions',
              type: ChallengeType.daily,
              xpReward: 60,
              requirements: {'repliesToday': 3}),
          const Challenge(
              id: 'd_view',
              title: 'Researcher',
              description: 'View 15 posts',
              type: ChallengeType.daily,
              xpReward: 40,
              requirements: {'viewsToday': 15}),
          const Challenge(
              id: 'd_discussion',
              title: 'Discussion Leader',
              description: 'Start 1 discussion',
              type: ChallengeType.daily,
              xpReward: 55,
              requirements: {'discussionsToday': 1}),
        ];

      case UserLevel.expert:
        return [
          const Challenge(
              id: 'd_post',
              title: 'Expert Writer',
              description: 'Create 4 insightful posts',
              type: ChallengeType.daily,
              xpReward: 90,
              requirements: {'postsToday': 4}),
          const Challenge(
              id: 'd_like',
              title: 'Community Builder',
              description: 'Like 12 posts',
              type: ChallengeType.daily,
              xpReward: 65,
              requirements: {'likesToday': 12}),
          const Challenge(
              id: 'd_reply',
              title: 'Expert Advisor',
              description: 'Reply to 5 discussions',
              type: ChallengeType.daily,
              xpReward: 80,
              requirements: {'repliesToday': 5}),
          const Challenge(
              id: 'd_discussion',
              title: 'Topic Starter',
              description: 'Start 2 discussions',
              type: ChallengeType.daily,
              xpReward: 75,
              requirements: {'discussionsToday': 2}),
          const Challenge(
              id: 'd_poll',
              title: 'Poll Master',
              description: 'Vote in 3 polls',
              type: ChallengeType.daily,
              xpReward: 50,
              requirements: {'pollsVotedToday': 3}),
        ];

      case UserLevel.master:
        return [
          const Challenge(
              id: 'd_post',
              title: 'Master Creator',
              description: 'Create 5 exceptional posts',
              type: ChallengeType.daily,
              xpReward: 110,
              requirements: {'postsToday': 5}),
          const Challenge(
              id: 'd_like',
              title: 'Engagement Master',
              description: 'Like 15 posts',
              type: ChallengeType.daily,
              xpReward: 80,
              requirements: {'likesToday': 15}),
          const Challenge(
              id: 'd_reply',
              title: 'Master Mentor',
              description: 'Reply to 7 discussions',
              type: ChallengeType.daily,
              xpReward: 100,
              requirements: {'repliesToday': 7}),
          const Challenge(
              id: 'd_discussion',
              title: 'Thought Leader',
              description: 'Start 3 discussions',
              type: ChallengeType.daily,
              xpReward: 95,
              requirements: {'discussionsToday': 3}),
          const Challenge(
              id: 'd_view',
              title: 'Master Researcher',
              description: 'View 25 posts',
              type: ChallengeType.daily,
              xpReward: 60,
              requirements: {'viewsToday': 25}),
        ];

      case UserLevel.legend:
        return [
          const Challenge(
              id: 'd_post',
              title: 'Legendary Content',
              description: 'Create 6 masterpiece posts',
              type: ChallengeType.daily,
              xpReward: 150,
              requirements: {'postsToday': 6}),
          const Challenge(
              id: 'd_like',
              title: 'Legend Support',
              description: 'Like 20 posts',
              type: ChallengeType.daily,
              xpReward: 100,
              requirements: {'likesToday': 20}),
          const Challenge(
              id: 'd_reply',
              title: 'Legendary Guide',
              description: 'Reply to 10 discussions',
              type: ChallengeType.daily,
              xpReward: 130,
              requirements: {'repliesToday': 10}),
          const Challenge(
              id: 'd_discussion',
              title: 'Visionary',
              description: 'Start 4 discussions',
              type: ChallengeType.daily,
              xpReward: 120,
              requirements: {'discussionsToday': 4}),
          const Challenge(
              id: 'd_poll',
              title: 'Poll Champion',
              description: 'Vote in 5 polls',
              type: ChallengeType.daily,
              xpReward: 80,
              requirements: {'pollsVotedToday': 5}),
        ];
    }
  }

  /// Generate level-appropriate weekly challenges
  static List<Challenge> _generateWeeklyChallengesForLevel(UserLevel level) {
    switch (level) {
      case UserLevel.beginner:
        return [
          const Challenge(
              id: 'w_posts',
              title: 'First Week',
              description: 'Create 3 posts this week',
              type: ChallengeType.weekly,
              xpReward: 100,
              requirements: {'postsThisWeek': 3}),
          const Challenge(
              id: 'w_replies',
              title: 'Helpful Beginner',
              description: 'Reply to 5 discussions',
              type: ChallengeType.weekly,
              xpReward: 120,
              requirements: {'repliesThisWeek': 5}),
          const Challenge(
              id: 'w_streak',
              title: 'Starting Streak',
              description: 'Maintain a 3 day streak',
              type: ChallengeType.weekly,
              xpReward: 90,
              requirements: {'streakDays': 3}),
          const Challenge(
              id: 'w_likes',
              title: 'Popular Start',
              description: 'Get 10 likes on your posts',
              type: ChallengeType.weekly,
              xpReward: 80,
              requirements: {'likesReceivedThisWeek': 10}),
        ];

      case UserLevel.intermediate:
        return [
          const Challenge(
              id: 'w_posts',
              title: 'Weekly Writer',
              description: 'Create 7 posts this week',
              type: ChallengeType.weekly,
              xpReward: 180,
              requirements: {'postsThisWeek': 7}),
          const Challenge(
              id: 'w_replies',
              title: 'Helpful Hand',
              description: 'Reply to 12 discussions',
              type: ChallengeType.weekly,
              xpReward: 200,
              requirements: {'repliesThisWeek': 12}),
          const Challenge(
              id: 'w_streak',
              title: 'Consistent',
              description: 'Maintain a 5 day streak',
              type: ChallengeType.weekly,
              xpReward: 150,
              requirements: {'streakDays': 5}),
          const Challenge(
              id: 'w_likes',
              title: 'Growing Popularity',
              description: 'Get 25 likes on your posts',
              type: ChallengeType.weekly,
              xpReward: 140,
              requirements: {'likesReceivedThisWeek': 25}),
        ];

      case UserLevel.advanced:
        return [
          const Challenge(
              id: 'w_posts',
              title: 'Prolific Writer',
              description: 'Create 10 posts this week',
              type: ChallengeType.weekly,
              xpReward: 250,
              requirements: {'postsThisWeek': 10}),
          const Challenge(
              id: 'w_replies',
              title: 'Community Pillar',
              description: 'Reply to 20 discussions',
              type: ChallengeType.weekly,
              xpReward: 280,
              requirements: {'repliesThisWeek': 20}),
          const Challenge(
              id: 'w_streak',
              title: 'Dedicated',
              description: 'Maintain a 7 day streak',
              type: ChallengeType.weekly,
              xpReward: 220,
              requirements: {'streakDays': 7}),
          const Challenge(
              id: 'w_likes',
              title: 'Influencer',
              description: 'Get 40 likes on your posts',
              type: ChallengeType.weekly,
              xpReward: 200,
              requirements: {'likesReceivedThisWeek': 40}),
        ];

      case UserLevel.expert:
        return [
          const Challenge(
              id: 'w_posts',
              title: 'Expert Publisher',
              description: 'Create 15 posts this week',
              type: ChallengeType.weekly,
              xpReward: 350,
              requirements: {'postsThisWeek': 15}),
          const Challenge(
              id: 'w_replies',
              title: 'Expert Guide',
              description: 'Reply to 30 discussions',
              type: ChallengeType.weekly,
              xpReward: 380,
              requirements: {'repliesThisWeek': 30}),
          const Challenge(
              id: 'w_streak',
              title: 'Devoted',
              description: 'Maintain a 7 day streak',
              type: ChallengeType.weekly,
              xpReward: 300,
              requirements: {'streakDays': 7}),
          const Challenge(
              id: 'w_discussions',
              title: 'Discussion Expert',
              description: 'Start 10 discussions',
              type: ChallengeType.weekly,
              xpReward: 320,
              requirements: {'discussionsThisWeek': 10}),
        ];

      case UserLevel.master:
        return [
          const Challenge(
              id: 'w_posts',
              title: 'Master Publisher',
              description: 'Create 20 posts this week',
              type: ChallengeType.weekly,
              xpReward: 450,
              requirements: {'postsThisWeek': 20}),
          const Challenge(
              id: 'w_replies',
              title: 'Master Advisor',
              description: 'Reply to 40 discussions',
              type: ChallengeType.weekly,
              xpReward: 500,
              requirements: {'repliesThisWeek': 40}),
          const Challenge(
              id: 'w_streak',
              title: 'Master Consistency',
              description: 'Maintain a 7 day streak',
              type: ChallengeType.weekly,
              xpReward: 400,
              requirements: {'streakDays': 7}),
          const Challenge(
              id: 'w_likes',
              title: 'Master Influence',
              description: 'Get 75 likes on your posts',
              type: ChallengeType.weekly,
              xpReward: 380,
              requirements: {'likesReceivedThisWeek': 75}),
        ];

      case UserLevel.legend:
        return [
          const Challenge(
              id: 'w_posts',
              title: 'Legendary Output',
              description: 'Create 30 posts this week',
              type: ChallengeType.weekly,
              xpReward: 600,
              requirements: {'postsThisWeek': 30}),
          const Challenge(
              id: 'w_replies',
              title: 'Legendary Mentor',
              description: 'Reply to 50 discussions',
              type: ChallengeType.weekly,
              xpReward: 650,
              requirements: {'repliesThisWeek': 50}),
          const Challenge(
              id: 'w_streak',
              title: 'Unstoppable',
              description: 'Maintain a 7 day streak',
              type: ChallengeType.weekly,
              xpReward: 500,
              requirements: {'streakDays': 7}),
          const Challenge(
              id: 'w_discussions',
              title: 'Legendary Leader',
              description: 'Start 20 discussions',
              type: ChallengeType.weekly,
              xpReward: 550,
              requirements: {'discussionsThisWeek': 20}),
        ];
    }
  }

  /// Get or Generate daily challenges based on user level
  Future<List<Challenge>> getDailyChallenges() async {
    final today = DateTime.now();
    final dateId = "${today.year}-${today.month}-${today.day}";
    final expiry = DateTime(today.year, today.month, today.day, 23, 59, 59);

    // Get user level to generate appropriate challenges
    final userLevel = await _getCurrentUserLevel();

    try {
      // Use user-specific document to store their level-based challenges
      final userId = _currentUserId ?? 'anonymous';
      final docRef = _firestore
          .collection('DailyChallenges')
          .doc(dateId)
          .collection('UserChallenges')
          .doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final list = (data?['challenges'] as List<dynamic>?)
            ?.map((e) => Challenge.fromMap(e))
            .toList();
        if (list != null && list.isNotEmpty) return list;
      }

      // Generate level-appropriate challenges if not exists
      final templates = _generateDailyChallengesForLevel(userLevel);
      final challenges = (templates..shuffle()).take(3).map((t) {
        return Challenge(
            id: "${t.id}_$dateId",
            title: t.title,
            description: t.description,
            type: t.type,
            xpReward: t.xpReward,
            requirements: t.requirements,
            expiresAt: expiry);
      }).toList();

      await docRef.set({
        'date': dateId,
        'userId': userId,
        'userLevel': userLevel.name,
        'challenges': challenges.map((c) => c.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return challenges;
    } catch (e) {
      debugPrint("Error fetching daily challenges: $e");
      // Fallback with beginner level challenge
      return [
        Challenge(
            id: 'fallback_daily',
            title: 'First Steps',
            description: 'Create 1 post',
            type: ChallengeType.daily,
            xpReward: 30,
            requirements: {'postsToday': 1},
            expiresAt: expiry),
      ];
    }
  }

  /// Get or Generate weekly challenges based on user level
  Future<List<Challenge>> getWeeklyChallenges() async {
    final now = DateTime.now();
    // Calculate week number (ISO 8601-ish)
    final days = now.difference(DateTime(now.year, 1, 1)).inDays;
    final weekNum = ((days + DateTime(now.year, 1, 1).weekday) / 7).ceil();
    final weekId = "${now.year}-W$weekNum";

    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    final expiry =
        DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);

    // Get user level to generate appropriate challenges
    final userLevel = await _getCurrentUserLevel();

    try {
      // Use user-specific document to store their level-based challenges
      final userId = _currentUserId ?? 'anonymous';
      final docRef = _firestore
          .collection('WeeklyChallenges')
          .doc(weekId)
          .collection('UserChallenges')
          .doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final list = (data?['challenges'] as List<dynamic>?)
            ?.map((e) => Challenge.fromMap(e))
            .toList();
        if (list != null && list.isNotEmpty) return list;
      }

      // Generate level-appropriate challenges if not exists
      final templates = _generateWeeklyChallengesForLevel(userLevel);
      final challenges = (templates..shuffle()).take(3).map((t) {
        return Challenge(
            id: "${t.id}_$weekId",
            title: t.title,
            description: t.description,
            type: t.type,
            xpReward: t.xpReward,
            requirements: t.requirements,
            expiresAt: expiry);
      }).toList();

      await docRef.set({
        'weekId': weekId,
        'userId': userId,
        'userLevel': userLevel.name,
        'challenges': challenges.map((c) => c.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return challenges;
    } catch (e) {
      debugPrint("Error fetching weekly challenges: $e");
      // Fallback with beginner level challenge
      return [
        Challenge(
            id: 'fallback_weekly',
            title: 'First Week',
            description: 'Create 3 posts this week',
            type: ChallengeType.weekly,
            xpReward: 100,
            requirements: {'postsThisWeek': 3},
            expiresAt: expiry),
      ];
    }
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

  // ==================== CACHE MANAGEMENT ====================

  GamificationStats? _cachedStats;
  DateTime? _lastStatsFetch;

  List<LeaderboardEntry>? _cachedLeaderboard;
  DateTime? _lastLeaderboardFetch;

  List<EarnedBadge>? _cachedBadges;
  DateTime? _lastBadgesFetch;

  static const Duration _cacheDuration = Duration(minutes: 5);

  GamificationStats? get cachedStats => _cachedStats;
  List<LeaderboardEntry>? get cachedLeaderboard => _cachedLeaderboard;
  List<EarnedBadge>? get cachedBadges => _cachedBadges;

  void clearCache() {
    _cachedStats = null;
    _lastStatsFetch = null;
    _cachedLeaderboard = null;
    _lastLeaderboardFetch = null;
    _cachedBadges = null;
    _lastBadgesFetch = null;
  }

  // ==================== BADGES MANAGEMENT ====================

  /// Get user's earned badges
  Future<List<EarnedBadge>> getUserBadges(
      {String? targetUserId, bool forceRefresh = false}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return [];

    // Return cached if valid
    if (!forceRefresh &&
        userId == _currentUserId &&
        _cachedBadges != null &&
        _lastBadgesFetch != null &&
        DateTime.now().difference(_lastBadgesFetch!) < _cacheDuration) {
      return _cachedBadges!;
    }

    try {
      final userDoc = await _firestore.collection('User').doc(userId).get();
      final badgesData = userDoc.data()?['badges'] as List<dynamic>?;
      final badges = badgesData == null
          ? <EarnedBadge>[]
          : badgesData
              .map((b) => EarnedBadge.fromMap(Map<String, dynamic>.from(b)))
              .toList();

      if (userId == _currentUserId) {
        _cachedBadges = badges;
        _lastBadgesFetch = DateTime.now();
      }

      return badges;
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

        // Invalidate cache
        if (userId == _currentUserId) {
          _cachedBadges = null;
          _cachedStats = null;
        }

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
  Future<List<LeaderboardEntry>> getLeaderboard(
      {int limit = 50, bool forceRefresh = false}) async {
    // Return cached if valid
    if (!forceRefresh &&
        _cachedLeaderboard != null &&
        _lastLeaderboardFetch != null &&
        DateTime.now().difference(_lastLeaderboardFetch!) < _cacheDuration) {
      return _cachedLeaderboard!;
    }

    try {
      // Query all users (XP is stored as string, so we can't orderBy on it directly)
      // We need to fetch and sort manually to ensure correct numeric ordering
      final querySnapshot = await _firestore
          .collection('User')
          .limit(500) // Fetch more than needed to ensure we get top users
          .get();

      // Parse and sort by XP as integers
      final userDataList = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        data['xpInt'] = int.tryParse(data['XP']?.toString() ?? '0') ?? 0;
        return data;
      }).toList();

      // Sort by XP descending (numeric sort)
      userDataList
          .sort((a, b) => (b['xpInt'] as int).compareTo(a['xpInt'] as int));

      // Take only the top 'limit' entries
      final topUsers = userDataList.take(limit).toList();

      // Assign ranks, handling ties (users with same XP get same rank)
      final entries = <LeaderboardEntry>[];
      int currentRank = 1;
      int? previousXp;

      for (int i = 0; i < topUsers.length; i++) {
        final data = topUsers[i];
        final xp = data['xpInt'] as int;

        // If XP is different from previous, update rank to current position
        if (previousXp != null && xp != previousXp) {
          currentRank = i + 1;
        }

        entries.add(LeaderboardEntry.fromMap(data, currentRank));
        previousXp = xp;
      }

      _cachedLeaderboard = entries;
      _lastLeaderboardFetch = DateTime.now();

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
      if (!userDoc.exists) return -1;

      final userXp =
          int.tryParse(userDoc.data()?['XP']?.toString() ?? '0') ?? 0;

      // Since XP is stored as string, we need to fetch all users and compare numerically
      // For better performance, we could cache this from the leaderboard call
      final allUsers = await _firestore.collection('User').get();

      // Count how many users have higher XP (numeric comparison)
      int higherRankedCount = 0;
      for (final doc in allUsers.docs) {
        final otherXp = int.tryParse(doc.data()['XP']?.toString() ?? '0') ?? 0;
        if (otherXp > userXp) {
          higherRankedCount++;
        }
      }

      return higherRankedCount + 1;
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return -1;
    }
  }

  // ==================== STATS ====================

  /// Get comprehensive gamification stats
  Future<GamificationStats> getGamificationStats(
      {String? targetUserId, bool forceRefresh = false}) async {
    final userId = targetUserId ?? _currentUserId;
    if (userId == null) return GamificationStats.empty();

    // Return cached if valid
    if (!forceRefresh &&
        userId == _currentUserId &&
        _cachedStats != null &&
        _lastStatsFetch != null &&
        DateTime.now().difference(_lastStatsFetch!) < _cacheDuration) {
      return _cachedStats!;
    }

    try {
      // Fetch user document
      final userDoc = await _firestore.collection('User').doc(userId).get();
      final userData = userDoc.data() ?? {};

      final totalXp = int.tryParse(userData['XP']?.toString() ?? '0') ?? 0;
      final level = UserLevel.fromXp(totalXp);

      // Fetch streak
      final streak = await getStreak(targetUserId: userId);

      // Fetch badges
      final badges =
          await getUserBadges(targetUserId: userId, forceRefresh: forceRefresh);

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

      final stats = GamificationStats(
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

      if (userId == _currentUserId) {
        _cachedStats = stats;
        _lastStatsFetch = DateTime.now();
      }

      return stats;
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
