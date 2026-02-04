import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _gamificationService = GamificationService();
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;
  int? _currentUserRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loading = true);
    try {
      final entries = await _gamificationService.getLeaderboard(limit: 100);
      final userRank = await _gamificationService.getUserRank();
      setState(() {
        _entries = entries;
        _currentUserRank = userRank;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: Column(
                children: [
                  // Current user rank card
                  if (_currentUserRank != null && _currentUserRank! > 0)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.primary.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 32),
                          const SizedBox(width: 12),
                          Text(
                            'Your Rank: #$_currentUserRank',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Top 3 podium
                  if (_entries.length >= 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // 2nd place
                          _buildPodiumItem(_entries[1], 2, 100, Colors.grey),
                          // 1st place
                          _buildPodiumItem(_entries[0], 1, 130, Colors.amber),
                          // 3rd place
                          _buildPodiumItem(
                              _entries[2], 3, 80, Colors.brown.shade300),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Rest of leaderboard
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _entries.length > 3 ? _entries.length - 3 : 0,
                      itemBuilder: (context, index) {
                        final entry = _entries[index + 3];
                        return _buildLeaderboardTile(entry);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPodiumItem(
      LeaderboardEntry entry, int rank, double height, Color color) {
    return Column(
      children: [
        // Profile pic
        CircleAvatar(
          radius: rank == 1 ? 35 : 28,
          backgroundImage: entry.profilePicture != null
              ? NetworkImage(entry.profilePicture!)
              : null,
          child: entry.profilePicture == null
              ? Text(entry.username.isNotEmpty
                  ? entry.username[0].toUpperCase()
                  : '?')
              : null,
        ),
        const SizedBox(height: 4),
        // Username
        Text(
          entry.username,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 14 : 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${entry.xp} XP',
          style: TextStyle(
            fontSize: rank == 1 ? 12 : 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        // Podium
        Container(
          width: rank == 1 ? 80 : 70,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rank == 1
                    ? '🥇'
                    : rank == 2
                        ? '🥈'
                        : '🥉',
                style: const TextStyle(fontSize: 24),
              ),
              Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundImage: entry.profilePicture != null
                  ? NetworkImage(entry.profilePicture!)
                  : null,
              child: entry.profilePicture == null
                  ? Text(entry.username.isNotEmpty
                      ? entry.username[0].toUpperCase()
                      : '?')
                  : null,
            ),
          ],
        ),
        title: Text(
          entry.username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(entry.level.icon),
            const SizedBox(width: 4),
            Text(entry.level.name),
            if (entry.badgeCount > 0) ...[
              const SizedBox(width: 8),
              Text('🏅 ${entry.badgeCount}'),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.xp}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'XP',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
