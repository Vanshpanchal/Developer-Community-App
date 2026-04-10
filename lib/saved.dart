import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/addpost.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_service.dart';
import 'utils/app_theme.dart';
import 'utils/content_moderation.dart';
import 'services/user_cache_service.dart';
import 'widgets/modern_widgets.dart';
import 'utils/app_snackbar.dart';

class saved extends StatefulWidget {
  const saved({super.key});

  @override
  savedState createState() => savedState();
}

class savedState extends State<saved>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String imageUrl = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  var exploreStream = FirebaseFirestore.instance
      .collection('Explore')
      .where('Report', isEqualTo: false)
      .snapshots();

  final savedIdsStream = FirebaseFirestore.instance
      .collection('User')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .snapshots();

  void openbottmsheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (ctx) => addpost());
  }

  fetchuser() async {
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('User')
          .doc(user?.uid)
          .get();
      if (userData.exists) {
        setState(() {
          username = userData['Username'] ?? 'No name available';
          imageUrl = userData['profilePicture'] ?? '';
        });
      } else {
        setState(() {
          username = 'No name available';
        });
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchuser();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Modern Header
              _buildHeader(theme),

              // Content
              Expanded(
                child: StreamBuilder(
                  stream: savedIdsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorState('Something went wrong');
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return _buildEmptyState();
                    }

                    List<String> documentIds =
                        List.from(snapshot.data!['Saved'] ?? []);

                    if (documentIds.isEmpty) {
                      return _buildEmptyState();
                    }

                    return FutureBuilder<List<DocumentSnapshot>>(
                      future: () async {
                        List<DocumentSnapshot> allDocs = [];
                        for(var i = 0; i < documentIds.length; i += 10) {
                          var chunk = documentIds.sublist(i, (i + 10 > documentIds.length) ? documentIds.length : i + 10);
                          final query = await FirebaseFirestore.instance.collection('Explore')
                              .where(FieldPath.documentId, whereIn: chunk).get();
                          allDocs.addAll(query.docs);
                        }
                        return allDocs;
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingState();
                        }
                        if (snapshot.hasError) {
                          return _buildErrorState(snapshot.error.toString());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _buildEmptyState();
                        }

                        var docs = snapshot.data!;

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration:
                                  Duration(milliseconds: 300 + (index * 100)),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: QuestionCard(
                                title: data['Title'] ?? '',
                                description: data['Description'] ?? '',
                                tags: List<String>.from(data['Tags'] ?? []),
                                votes: data['likescount'] ?? 0,
                                answers: data['answers'] ?? 0,
                                timestamp: (data['Timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now(),
                                code: data['code'] ?? '',
                                uid: data['Uid'] ?? '',
                                docid: docs[index].id,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bookmark_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saved Posts',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Your bookmarked content',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListShimmer(itemCount: 4),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_outline_rounded,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No saved posts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark posts to see them here',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionCard extends StatefulWidget {
  final String title;
  final String description;
  final String? code;
  final List<String> tags;
  final int votes;
  final int answers;
  final String uid;
  final String docid;
  final DateTime timestamp;

  const QuestionCard({
    super.key,
    required this.title,
    required this.code,
    required this.description,
    required this.tags,
    required this.votes,
    required this.answers,
    required this.timestamp,
    required this.uid,
    required this.docid,
  });

  @override
  _QuestionCardState createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  bool isSaved = false;
  bool isLiked = false;
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = UserCacheService.instance.getUserData(widget.uid);
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await _checkIfLiked();
    await _checkIfSaved();
  }

  Future<void> _checkIfLiked() async {
    try {
      DocumentReference questionRef =
          FirebaseFirestore.instance.collection('Explore').doc(widget.docid);
      DocumentSnapshot questionDoc = await questionRef.get();
      if (questionDoc.exists) {
        var likes = questionDoc['likes'];
        if (likes is List) {
          setState(() {
            isLiked = likes.contains(FirebaseAuth.instance.currentUser
                ?.uid);
          });
        } else {
          setState(() {
            isLiked = false;
          });
        }
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        List<dynamic> saved = userDoc['Saved'] ?? [];
        setState(() {
          isSaved = saved.contains(widget.docid);
        });
      }
    } catch (e) {
      print('Error checking saved status: $e');
    }
  }

  Future<void> _handleLike() async {
    try {
      DocumentReference questionRef =
          FirebaseFirestore.instance.collection('Explore').doc(widget.docid);
      DocumentSnapshot questionDoc = await questionRef.get();

      if (questionDoc.exists) {
        var likes = questionDoc['likes'] as List<dynamic>? ?? [];
        bool actuallyLiked =
            likes.contains(FirebaseAuth.instance.currentUser?.uid);

        if (actuallyLiked) {
          await questionRef.update({
            'likes': FieldValue.arrayRemove(
                [FirebaseAuth.instance.currentUser?.uid]),
          });
        } else {
          await questionRef.update({
            'likes':
                FieldValue.arrayUnion([FirebaseAuth.instance.currentUser?.uid]),
          });
        }

        DocumentSnapshot updatedDoc = await questionRef.get();
        List<dynamic> updatedLikes = updatedDoc['likes'] ?? [];

        await questionRef.update({
          'likescount': updatedLikes.length,
        });

        setState(() {
          isLiked = !actuallyLiked;
        });
      }
    } catch (e) {
      print('Error handling like/dislike: $e');
      await _checkIfLiked();
    }
  }

  removesaved(itemId) async {
    try {
      var usercredential = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection("User")
          .doc(usercredential?.uid)
          .update({
        'Saved': FieldValue.arrayRemove([itemId])
      });
      AppSnackbar.success('Unsaved the post');
    } catch (e) {
      AppSnackbar.error('Failed to unsave post');
    }
  }

  save(itemId) async {
    var usercredential = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection("User")
        .doc(usercredential?.uid)
        .update({
      'Saved': FieldValue.arrayUnion([itemId])
    });
  }

  bool _showComplexity = false;
  String? _complexityResult;
  bool _complexityLoading = false;
  bool _showFullCode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Row
            FutureBuilder<Map<String, dynamic>>(
              future: _userDataFuture,
              builder: (context, snapshot) {
                final userData = snapshot.data ?? {};
                final imageUrl = userData['profilePicture'] as String?;
                final hasImage = imageUrl != null && imageUrl.isNotEmpty;
                final userName = userData['Username']?.toString() ?? 'Loading...';
                final userXP = userData['XP']?.toString();

                return Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        foregroundImage: hasImage
                                ? NetworkImage(imageUrl)
                                : const NetworkImage(
                                    'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                                  ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatDate(widget.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (userXP != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$userXP XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Description
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                children: _buildDescription(widget.description, theme),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Code Block Preview or Full
            if (widget.code != null && widget.code!.isNotEmpty)
              _showFullCode ? _buildCodeBlock(theme) : _buildCodePreview(theme),

            if (widget.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Tags
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Actions Row
            Row(
              children: [
                _buildCompactAction(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${widget.votes}',
                  onTap: _handleLike,
                  theme: theme,
                  isActive: isLiked,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.bookmark_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => removesaved(widget.docid),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodePreview(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final codeLines = widget.code?.split('\n') ?? [];
    final previewLines = codeLines.take(4).join('\n');
    final hasMore = codeLines.length > 4;

    return InkWell(
      onTap: () => setState(() => _showFullCode = true),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Code Snippet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (hasMore) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tap to expand',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
            // Code content
            Container(
              padding: const EdgeInsets.all(12),
              child: Text(
                previewLines,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBlock(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Code Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Code Snippet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                // Copy button
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 14),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.code!));
                    AppSnackbar.success('Code copied to clipboard', title: 'Copied!');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy code',
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // Analyze button
                _buildAnalyzeButton(theme),
                const SizedBox(width: 8),
                // Collapse button
                IconButton(
                  icon: Icon(Icons.expand_less_rounded, size: 16),
                  onPressed: () => setState(() => _showFullCode = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Collapse',
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),

          // Code Content
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Text(
                widget.code!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),
          ),

          // Complexity Result
          if (_showComplexity && _complexityResult != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Complexity Analysis',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: _complexityResult!,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodySmall,
                      h1: theme.textTheme.titleSmall,
                      h2: theme.textTheme.titleSmall,
                      h3: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton(ThemeData theme) {
    if (_complexityLoading) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }

    return IconButton(
      icon: Icon(
        _showComplexity ? Icons.visibility_off_rounded : Icons.speed_rounded,
        size: 14,
      ),
      onPressed: () async {
        if (_showComplexity) {
          setState(() => _showComplexity = false);
          return;
        }
        if (widget.code != null && widget.code!.trim().isNotEmpty) {
          setState(() => _complexityLoading = true);
          final res = await AIService()
              .analyzeComplexity(code: widget.code!, language: 'dart');
          if (mounted) {
            setState(() {
              _complexityResult = res;
              _showComplexity = true;
              _complexityLoading = false;
            });
          }
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      tooltip: _showComplexity ? 'Hide analysis' : 'Analyze complexity',
      color: theme.colorScheme.primary,
    );
  }

  Widget _buildCompactAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive
                ? AppTheme.primaryColor
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isActive
                  ? AppTheme.primaryColor
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

List<TextSpan> _buildDescription(String description, ThemeData theme) {
  final urlRegex = RegExp(r'(https?://[^\s]+)'); // Matches URLs
  final matches = urlRegex.allMatches(description);

  if (matches.isEmpty) {
    return [TextSpan(text: description)];
  }

  int lastMatchEnd = 0;
  List<TextSpan> spans = [];

  for (final match in matches) {
    // Add text before the URL
    if (match.start > lastMatchEnd) {
      spans.add(
          TextSpan(text: description.substring(lastMatchEnd, match.start)));
    }

    // Add the URL as a clickable link
    final url = description.substring(match.start, match.end);
    spans.add(
      TextSpan(
        text: url,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL(url),
      ),
    );

    lastMatchEnd = match.end;
  }

  // Add remaining text after the last URL
  if (lastMatchEnd < description.length) {
    spans.add(TextSpan(text: description.substring(lastMatchEnd)));
  }

  return spans;
}

// Function to launch URLs
void _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('Could not launch $url');
  }
}
