import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_snackbar.dart';

class PortfolioSummaryPage extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> discussions;
  final List<Map<String, dynamic>> explorePosts;
  final List<Map<String, dynamic>> replies;
  final String? githubUsername;

  const PortfolioSummaryPage({
    super.key,
    this.userId,
    required this.stats,
    required this.discussions,
    required this.explorePosts,
    required this.replies,
    this.githubUsername,
  });

  @override
  State<PortfolioSummaryPage> createState() => _PortfolioSummaryPageState();
}

class _PortfolioSummaryPageState extends State<PortfolioSummaryPage> {
  final _auth = FirebaseAuth.instance;
  bool _aiLoading = false;
  String? _aiSummary;
  bool _editing = false;
  final _editController = TextEditingController();
  Map<String, dynamic>? _githubStats;

  @override
  void initState() {
    super.initState();
    _generateAISummary();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _generateAISummary() async {
    if (_aiLoading) return;
    setState(() {
      _aiLoading = true;
      _aiSummary = null;
    });
    try {
      final user = _auth.currentUser;
      await _maybeFetchGithub();
      final mergedStats = {
        ...widget.stats,
        if (_githubStats != null) 'github': _githubStats
      };
      final summary = await AIService().generatePortfolioSummary(
        stats: mergedStats,
        github: _githubStats,
        userHandle: user?.email,
      );
      if (summary == AIService.missingKeyMessage) {
        if (mounted) _showMissingKeyDialog();
      } else if (mounted) {
        setState(() {
          _aiSummary = summary;
          _editController.text = summary;
        });
        _storeHistory(summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSummary = 'AI summary failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _aiLoading = false;
        });
      }
    }
  }

  Future<void> _maybeFetchGithub() async {
    if (_githubStats != null) return;
    if (widget.githubUsername == null || widget.githubUsername!.isEmpty) return;

    final uid = widget.userId ?? _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final gh = widget.githubUsername!;
      final headers = {'User-Agent': 'DevCommunityApp'};
      final userResp = await http
          .get(Uri.parse('https://api.github.com/users/$gh'), headers: headers);
      if (userResp.statusCode != 200) return;
      final data = jsonDecode(userResp.body) as Map<String, dynamic>;
      _githubStats = {
        'public_repos': data['public_repos'],
        'followers': data['followers'],
        'following': data['following'],
        'bio': data['bio'],
        'location': data['location'],
        'company': data['company'],
      };
    } catch (e) {
      print('Error fetching GitHub stats: $e');
    }
  }

  void _showMissingKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key Needed'),
        content: const Text(
            'To generate an AI portfolio summary, please add your Gemini API key in settings.'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _storeHistory(String summary) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .collection('PortfolioHistory')
          .add({
        'summary': summary,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error storing summary: $e');
    }
  }

  Future<void> _saveSummary() async {
    final newSummary = _editController.text.trim();
    if (newSummary.isEmpty) return;
    setState(() {
      _aiSummary = newSummary;
      _editing = false;
    });
    await _storeHistory(newSummary);
    AppSnackbar.success('Summary saved successfully!', title: 'Success');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_fix_high_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'AI Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.7)
                    ],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
              ),
            ),
          ],
        ),
        actions: [
          if (_aiSummary != null && !_editing)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.share(_aiSummary!);
              },
              tooltip: 'Share Summary',
            ),
          if (_aiSummary != null && !_editing)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _aiSummary!));
                AppSnackbar.success('Summary copied to clipboard!');
              },
              tooltip: 'Copy to Clipboard',
            ),
        ],
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Overview Card
          _buildStatsCard(theme, isDark),
          const SizedBox(height: 20),

          // Summary Section
          if (_aiLoading)
            _buildLoadingCard(theme, isDark)
          else if (_aiSummary != null)
            _buildSummaryCard(theme, isDark)
          else
            _buildErrorCard(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Portfolio Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            'Discussions',
            widget.stats['discussionCount'].toString(),
            Icons.forum,
            theme,
            isDark,
          ),
          _buildStatRow(
            'Posts',
            widget.stats['explorePostCount'].toString(),
            Icons.article,
            theme,
            isDark,
          ),
          _buildStatRow(
            'Replies',
            widget.stats['replyCount'].toString(),
            Icons.comment,
            theme,
            isDark,
          ),
          if (_githubStats != null) ...[
            const Divider(height: 24),
            _buildStatRow(
              'GitHub Repos',
              _githubStats!['public_repos'].toString(),
              Icons.code,
              theme,
              isDark,
            ),
            _buildStatRow(
              'GitHub Followers',
              _githubStats!['followers'].toString(),
              Icons.people,
              theme,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(
      String label, String value, IconData icon, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Generating AI Summary...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing your portfolio data with AI',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI-Generated Summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_editing)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    setState(() {
                      _editing = true;
                    });
                  },
                  tooltip: 'Edit Summary',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_editing)
            Column(
              children: [
                TextField(
                  controller: _editController,
                  maxLines: 15,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: 'Edit your summary...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editing = false;
                          _editController.text = _aiSummary!;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveSummary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            )
          else
            MarkdownBody(
              data: _aiSummary!,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                h1: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                h2: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                h3: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                code: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
                listBullet: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateAISummary,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Generate Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _generateAISummary,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
