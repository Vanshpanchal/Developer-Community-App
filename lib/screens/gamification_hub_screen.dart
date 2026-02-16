import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';
import '../widgets/gamification_widgets.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';
import 'challenges_screen.dart';

class GamificationHubScreen extends StatefulWidget {
  const GamificationHubScreen({super.key});

  @override
  State<GamificationHubScreen> createState() => _GamificationHubScreenState();
}

class _GamificationHubScreenState extends State<GamificationHubScreen> {
  final _gamificationService = GamificationService();
  GamificationStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Record activity for streak
    _gamificationService.recordActivity();
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    // Check cache first
    final cached = _gamificationService.cachedStats;
    if (cached != null && !forceRefresh) {
      if (mounted) {
        setState(() {
          _stats = cached;
          _loading = false;
        });
      }
    } else {
      setState(() => _loading = true);
    }

    try {
      final stats = await _gamificationService.getGamificationStats(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎮 Gamification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const GamificationHubShimmer()
          : _stats == null
              ? const Center(child: Text('Failed to load stats'))
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level Progress Card
                        LevelProgressCard(
                          stats: _stats!,
                          onTap: () => _showLevelInfo(),
                        ),

                        // Quick Actions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  '🏆',
                                  'Leaderboard',
                                  'See rankings',
                                  () => Get.to(() => const LeaderboardScreen()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  '🎯',
                                  'Challenges',
                                  'Daily & Weekly',
                                  () => Get.to(() => const ChallengesScreen()),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Streak Widget
                        StreakWidget(streak: _stats!.streak),

                        // Badges Showcase
                        BadgeShowcase(
                          badges: _stats!.badges,
                          onViewAll: () => Get.to(() => const BadgesScreen()),
                        ),

                        // Active Challenges Preview
                        _buildChallengesPreview(),

                        // XP History / Recent Activity
                        _buildRecentActivity(),

                        // Level Guide
                        _buildLevelGuide(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildQuickActionCard(
    String emoji,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengesPreview() {
    final theme = Theme.of(context);

    return FutureBuilder<List<Challenge>>(
        future: _gamificationService.getDailyChallenges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink(); // Or loading shimmer
          }

          final dailyChallenges = snapshot.data!;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🎯 Today\'s Challenges',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Get.to(() => const ChallengesScreen()),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...dailyChallenges.take(2).map((challenge) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(challenge.type.icon),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    challenge.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    challenge.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+${challenge.xpReward}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildRecentActivity() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 XP Earning Guide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildXpActionRow(XpAction.createPost),
            _buildXpActionRow(XpAction.createDiscussion),
            _buildXpActionRow(XpAction.postReply),
            _buildXpActionRow(XpAction.receiveLike),
            _buildXpActionRow(XpAction.dailyLogin),
            _buildXpActionRow(XpAction.streakBonus),
            _buildXpActionRow(XpAction.pollCreated),
          ],
        ),
      ),
    );
  }

  Widget _buildXpActionRow(XpAction action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action.description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            '+${action.defaultXp} XP',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelGuide() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Level Guide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...UserLevel.values.map((level) {
              final isCurrent = _stats?.level == level;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Text(level.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          Text(
                            '${level.minXp}+ XP required',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLevelInfo() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _stats!.level.icon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              _stats!.level.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_stats!.totalXp} XP',
              style: TextStyle(
                fontSize: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            if (_stats!.level.nextLevel != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress to ${_stats!.level.nextLevel!.name}'),
                  Text(
                      '${(_stats!.progressToNextLevel * 100).toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _stats!.progressToNextLevel,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_stats!.xpToNextLevel} XP to go',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ] else ...[
              const Text(
                '🎉 You\'ve reached the maximum level!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
