/// Gamification models for DevSphere

// User Level based on XP
enum UserLevel {
  beginner(0, 'Beginner', '🌱'),
  intermediate(500, 'Intermediate', '🌿'),
  advanced(1500, 'Advanced', '🌳'),
  expert(3500, 'Expert', '⭐'),
  master(7000, 'Master', '🏆'),
  legend(15000, 'Legend', '👑');

  final int minXp;
  final String name;
  final String icon;

  const UserLevel(this.minXp, this.name, this.icon);

  static UserLevel fromXp(int xp) {
    final levels = UserLevel.values.reversed;
    for (final level in levels) {
      if (xp >= level.minXp) return level;
    }
    return UserLevel.beginner;
  }

  UserLevel? get nextLevel {
    final idx = UserLevel.values.indexOf(this);
    if (idx < UserLevel.values.length - 1) {
      return UserLevel.values[idx + 1];
    }
    return null;
  }

  int get xpToNextLevel {
    final next = nextLevel;
    return next?.minXp ?? minXp;
  }
}

// Badge Categories
enum BadgeCategory {
  posts('Posts', '📝'),
  discussions('Discussions', '💬'),
  engagement('Engagement', '🤝'),
  streak('Streak', '🔥'),
  special('Special', '✨'),
  milestone('Milestone', '🎯');

  final String name;
  final String icon;

  const BadgeCategory(this.name, this.icon);
}

// Badge Rarity
enum BadgeRarity {
  common('Common', 0xFF9E9E9E),
  uncommon('Uncommon', 0xFF4CAF50),
  rare('Rare', 0xFF2196F3),
  epic('Epic', 0xFF9C27B0),
  legendary('Legendary', 0xFFFF9800);

  final String name;
  final int color;

  const BadgeRarity(this.name, this.color);
}

// Badge Definition
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final int xpReward;
  final Map<String, dynamic> criteria;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.rarity,
    required this.xpReward,
    required this.criteria,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'category': category.name,
        'rarity': rarity.name,
        'xpReward': xpReward,
        'criteria': criteria,
      };

  factory Badge.fromMap(Map<String, dynamic> map) => Badge(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        icon: map['icon'] ?? '🏅',
        category: BadgeCategory.values.firstWhere(
          (e) => e.name == map['category'],
          orElse: () => BadgeCategory.special,
        ),
        rarity: BadgeRarity.values.firstWhere(
          (e) => e.name == map['rarity'],
          orElse: () => BadgeRarity.common,
        ),
        xpReward: map['xpReward'] ?? 0,
        criteria: Map<String, dynamic>.from(map['criteria'] ?? {}),
      );
}

// User's earned badge
class EarnedBadge {
  final String badgeId;
  final DateTime earnedAt;

  const EarnedBadge({
    required this.badgeId,
    required this.earnedAt,
  });

  Map<String, dynamic> toMap() => {
        'badgeId': badgeId,
        'earnedAt': earnedAt.toIso8601String(),
      };

  factory EarnedBadge.fromMap(Map<String, dynamic> map) => EarnedBadge(
        badgeId: map['badgeId'] ?? '',
        earnedAt: DateTime.tryParse(map['earnedAt'] ?? '') ?? DateTime.now(),
      );
}

// Daily Streak
class DailyStreak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final List<DateTime> activityHistory;

  const DailyStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
    this.activityHistory = const [],
  });

  bool get isActiveToday {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    return lastActivityDate!.year == now.year &&
        lastActivityDate!.month == now.month &&
        lastActivityDate!.day == now.day;
  }

  bool get willLoseStreak {
    if (lastActivityDate == null) return currentStreak > 0;
    final now = DateTime.now();
    final diff = now.difference(lastActivityDate!).inDays;
    return diff > 1;
  }

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': lastActivityDate?.toIso8601String(),
        'activityHistory':
            activityHistory.map((d) => d.toIso8601String()).toList(),
      };

  factory DailyStreak.fromMap(Map<String, dynamic> map) => DailyStreak(
        currentStreak: map['currentStreak'] ?? 0,
        longestStreak: map['longestStreak'] ?? 0,
        lastActivityDate: map['lastActivityDate'] != null
            ? DateTime.tryParse(map['lastActivityDate'])
            : null,
        activityHistory: (map['activityHistory'] as List<dynamic>?)
                ?.map((e) => DateTime.parse(e.toString()))
                .toList() ??
            [],
      );

  factory DailyStreak.empty() => const DailyStreak(
        currentStreak: 0,
        longestStreak: 0,
      );
}

// Challenge/Quest Status
enum ChallengeStatus {
  available,
  inProgress,
  completed,
  expired,
}

// Challenge Type
enum ChallengeType {
  daily('Daily', '📅', 1),
  weekly('Weekly', '📆', 7),
  monthly('Monthly', '🗓️', 30),
  special('Special', '🌟', 0);

  final String name;
  final String icon;
  final int durationDays;

  const ChallengeType(this.name, this.icon, this.durationDays);
}

// Challenge Definition
class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int xpReward;
  final String? badgeReward;
  final Map<String, dynamic> requirements;
  final DateTime? expiresAt;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.xpReward,
    this.badgeReward,
    required this.requirements,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'xpReward': xpReward,
        'badgeReward': badgeReward,
        'requirements': requirements,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory Challenge.fromMap(Map<String, dynamic> map) => Challenge(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        type: ChallengeType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => ChallengeType.daily,
        ),
        xpReward: map['xpReward'] ?? 0,
        badgeReward: map['badgeReward'],
        requirements: Map<String, dynamic>.from(map['requirements'] ?? {}),
        expiresAt: map['expiresAt'] != null
            ? DateTime.tryParse(map['expiresAt'])
            : null,
      );
}

// User's challenge progress
class UserChallenge {
  final String challengeId;
  final ChallengeStatus status;
  final Map<String, dynamic> progress;
  final DateTime startedAt;
  final DateTime? completedAt;

  const UserChallenge({
    required this.challengeId,
    required this.status,
    required this.progress,
    required this.startedAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'challengeId': challengeId,
        'status': status.name,
        'progress': progress,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory UserChallenge.fromMap(Map<String, dynamic> map) => UserChallenge(
        challengeId: map['challengeId'] ?? '',
        status: ChallengeStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => ChallengeStatus.available,
        ),
        progress: Map<String, dynamic>.from(map['progress'] ?? {}),
        startedAt: DateTime.tryParse(map['startedAt'] ?? '') ?? DateTime.now(),
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'])
            : null,
      );
}

// Leaderboard Entry
class LeaderboardEntry {
  final String odId;
  final String username;
  final String? profilePicture;
  final int xp;
  final int rank;
  final UserLevel level;
  final int badgeCount;

  const LeaderboardEntry({
    required this.odId,
    required this.username,
    this.profilePicture,
    required this.xp,
    required this.rank,
    required this.level,
    required this.badgeCount,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, int rank) =>
      LeaderboardEntry(
        odId: map['uid'] ?? '',
        username: map['Username'] ?? map['username'] ?? 'Unknown',
        profilePicture: map['profilePicture'],
        xp: int.tryParse(map['XP']?.toString() ?? '0') ?? 0,
        rank: rank,
        level:
            UserLevel.fromXp(int.tryParse(map['XP']?.toString() ?? '0') ?? 0),
        badgeCount: (map['badges'] as List<dynamic>?)?.length ?? 0,
      );
}

// XP Action types and rewards
enum XpAction {
  createPost(50, 'Created a post'),
  createDiscussion(40, 'Started a discussion'),
  postReply(15, 'Posted a reply'),
  receiveLike(5, 'Received a like'),
  giveLike(2, 'Gave a like'),
  dailyLogin(10, 'Daily login'),
  streakBonus(25, 'Streak bonus'),
  completeChallenge(0, 'Completed challenge'), // Variable XP
  earnBadge(0, 'Earned badge'), // Variable XP
  helpfulAnswer(30, 'Marked as helpful'),
  firstPost(100, 'First post bonus'),
  pollCreated(20, 'Created a poll'),
  pollVote(5, 'Voted in a poll');

  final int defaultXp;
  final String description;

  const XpAction(this.defaultXp, this.description);
}

// Gamification Stats
class GamificationStats {
  final int totalXp;
  final UserLevel level;
  final DailyStreak streak;
  final List<EarnedBadge> badges;
  final List<UserChallenge> activeChallenges;
  final int postsCount;
  final int discussionsCount;
  final int repliesCount;
  final int likesReceived;
  final int likesGiven;
  final int pollsCreated;
  final int pollsVoted;

  const GamificationStats({
    required this.totalXp,
    required this.level,
    required this.streak,
    required this.badges,
    required this.activeChallenges,
    required this.postsCount,
    required this.discussionsCount,
    required this.repliesCount,
    required this.likesReceived,
    required this.likesGiven,
    required this.pollsCreated,
    required this.pollsVoted,
  });

  double get progressToNextLevel {
    final next = level.nextLevel;
    if (next == null) return 1.0;
    final currentMin = level.minXp;
    final nextMin = next.minXp;
    return (totalXp - currentMin) / (nextMin - currentMin);
  }

  int get xpToNextLevel {
    final next = level.nextLevel;
    if (next == null) return 0;
    return next.minXp - totalXp;
  }

  factory GamificationStats.empty() => GamificationStats(
        totalXp: 0,
        level: UserLevel.beginner,
        streak: DailyStreak.empty(),
        badges: [],
        activeChallenges: [],
        postsCount: 0,
        discussionsCount: 0,
        repliesCount: 0,
        likesReceived: 0,
        likesGiven: 0,
        pollsCreated: 0,
        pollsVoted: 0,
      );
}
