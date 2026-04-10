import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';
import '../widgets/modern_widgets.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  final _gamificationService = GamificationService();
  late TabController _tabController;
  bool _loading = false;
  GamificationStats? _stats;

  List<Challenge> _dailyChallenges = [];
  List<Challenge> _weeklyChallenges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() => _loading = true);
    try {
      final daily = await _gamificationService.getDailyChallenges();
      final weekly = await _gamificationService.getWeeklyChallenges();

      if (mounted) {
        setState(() {
          _dailyChallenges = daily;
          _weeklyChallenges = weekly;
          _stats = null;
          _loading = false;
        });
      }

      final stats = await _gamificationService.getGamificationStats(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _stats = stats;
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
        title: const Text('🎯 Challenges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '📅 Daily'),
            Tab(text: '📆 Weekly'),
          ],
        ),
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: ListShimmer(itemCount: 6, showAvatar: false, lineCount: 3),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChallengeList(_dailyChallenges, ChallengeType.daily),
                _buildChallengeList(_weeklyChallenges, ChallengeType.weekly),
              ],
            ),
    );
  }

  Widget _buildChallengeList(List<Challenge> challenges, ChallengeType type) {
    if (challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type.icon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type.name.toLowerCase()} challenges available',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: challenges.length,
        itemBuilder: (context, index) {
          return _buildChallengeCard(challenges[index]);
        },
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final timeLeft = challenge.expiresAt?.difference(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showChallengeDetails(challenge),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      challenge.type.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // XP Reward
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${challenge.xpReward} XP',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time remaining
                  if (timeLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(timeLeft),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              Builder(builder: (context) {
                final progressData = _calculateProgress(challenge);
                final progress = progressData.$1;
                final currentValue = progressData.$2;
                final targetValue = progressData.$3;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Progress: ${(progress * 100).toStringAsFixed(0)}% ($currentValue/$targetValue)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  (double, int, int) _calculateProgress(Challenge challenge) {
    if (_stats == null || challenge.requirements.isEmpty) {
      return (0.0, 0, 1);
    }

    final requirement = challenge.requirements.entries.first;
    final key = requirement.key;
    final target = (requirement.value as num?)?.toInt() ?? 1;

    int current = 0;
    switch (key) {
      case 'postsToday':
      case 'postsThisWeek':
      case 'postsCount':
        current = _stats!.postsCount;
        break;
      case 'discussionsToday':
      case 'discussionsThisWeek':
      case 'discussionsCount':
        current = _stats!.discussionsCount;
        break;
      case 'repliesToday':
      case 'repliesThisWeek':
      case 'repliesCount':
        current = _stats!.repliesCount;
        break;
      case 'likesGivenToday':
      case 'likesGivenThisWeek':
      case 'likesGiven':
        current = _stats!.likesGiven;
        break;
      case 'likesReceived':
        current = _stats!.likesReceived;
        break;
      case 'pollsCreated':
        current = _stats!.pollsCreated;
        break;
      case 'pollsVoted':
        current = _stats!.pollsVoted;
        break;
      case 'streakDays':
      case 'streak':
        current = _stats!.streak.currentStreak;
        break;
      default:
        current = 0;
    }

    final safeTarget = target <= 0 ? 1 : target;
    final progress = (current / safeTarget).clamp(0.0, 1.0);
    return (progress, current, safeTarget);
  }

  void _showChallengeDetails(Challenge challenge) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              challenge.type.icon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              challenge.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                challenge.type.name,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              challenge.description,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Requirements:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...challenge.requirements.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 8),
                    Text('${_formatRequirement(e.key)}: ${e.value}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  '+${challenge.xpReward} XP',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h left';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m left';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m left';
    }
    return 'Expiring soon';
  }

  String _formatRequirement(String key) {
    // Convert camelCase to readable text
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .replaceAll('Today', ' today')
        .replaceAll('ThisWeek', ' this week')
        .trim()
        .toLowerCase()
        .replaceFirst(key[0].toLowerCase(), key[0].toUpperCase());
  }
}
