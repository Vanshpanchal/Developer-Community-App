import 'package:flutter/material.dart' hide Badge;
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class BadgesScreen extends StatefulWidget {
  final String? userId;

  const BadgesScreen({super.key, this.userId});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _gamificationService = GamificationService();
  List<EarnedBadge> _earnedBadges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _loading = true);
    try {
      final badges = await _gamificationService.getUserBadges(
        targetUserId: widget.userId,
      );
      setState(() => _earnedBadges = badges);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏅 Badges'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: BadgeCategory.values.length + 1,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'All'),
                      ...BadgeCategory.values.map(
                        (cat) => Tab(text: '${cat.icon} ${cat.name}'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBadgeGrid(GamificationService.allBadges),
                        ...BadgeCategory.values.map(
                          (cat) => _buildBadgeGrid(
                            GamificationService.allBadges
                                .where((b) => b.category == cat)
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBadgeGrid(List<Badge> badges) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isEarned = _earnedBadges.any((e) => e.badgeId == badge.id);
        final earnedBadge = isEarned
            ? _earnedBadges.firstWhere((e) => e.badgeId == badge.id)
            : null;

        return _buildBadgeCard(badge, isEarned, earnedBadge);
      },
    );
  }

  Widget _buildBadgeCard(Badge badge, bool isEarned, EarnedBadge? earnedBadge) {
    return GestureDetector(
      onTap: () => _showBadgeDetails(badge, isEarned, earnedBadge),
      child: Container(
        decoration: BoxDecoration(
          color: isEarned
              ? Color(badge.rarity.color).withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEarned ? Color(badge.rarity.color) : Colors.grey.shade300,
            width: isEarned ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              badge.icon,
              style: TextStyle(
                fontSize: 36,
                color: isEarned ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isEarned ? Colors.black87 : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Color(badge.rarity.color)
                    .withValues(alpha: isEarned ? 0.3 : 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge.rarity.name,
                style: TextStyle(
                  fontSize: 9,
                  color: isEarned ? Color(badge.rarity.color) : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(Badge badge, bool isEarned, EarnedBadge? earnedBadge) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badge.icon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Color(badge.rarity.color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge.rarity.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.description,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '+${badge.xpReward} XP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEarned && earnedBadge != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Earned on ${_formatDate(earnedBadge.earnedAt)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Not yet earned',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
