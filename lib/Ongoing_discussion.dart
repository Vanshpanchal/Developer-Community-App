import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/add_discussion.dart';
import 'package:developer_community_app/detail_discussion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utils/app_theme.dart';
import 'widgets/modern_widgets.dart';
import 'dart:math' as math;

class ongoing_discussion extends StatefulWidget {
  const ongoing_discussion({super.key});

  @override
  State<ongoing_discussion> createState() => _ongoing_discussionState();
}

class _ongoing_discussionState extends State<ongoing_discussion>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String imageUrl = '';
  TextEditingController search_controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  var discussionStream = FirebaseFirestore.instance
      .collection('Discussions')
      .where('Report', isEqualTo: false)
      .snapshots();

  all() {
    setState(() {
      discussionStream = FirebaseFirestore.instance
          .collection('Discussions')
          .where('Report', isEqualTo: false)
          .snapshots();
    });
    search_controller.clear();
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

  String _searchQuery = '';
  List<QueryDocumentSnapshot> _allDiscussions = [];
  List<QueryDocumentSnapshot> _filteredDiscussions = [];

  onSearch2(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  List<QueryDocumentSnapshot> _performSearch(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    // Store all discussions
    _allDiscussions = docs;

    // Calculate relevance scores for each document
    final scoredDocs = docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final score = SearchAlgorithm.calculateRelevance(
            query: _searchQuery,
            title: data['Title']?.toString() ?? '',
            description: data['Description']?.toString() ?? '',
            tags: List<String>.from(data['Tags'] ?? []),
          );
          return {'doc': doc, 'score': score};
        })
        .where((item) => (item['score'] as double) > 0.0)
        .toList();

    // Sort by relevance score (highest first)
    scoredDocs.sort(
        (a, b) => (b['score']! as double).compareTo(a['score']! as double));

    // Return sorted documents
    return scoredDocs
        .map((item) => item['doc']! as QueryDocumentSnapshot)
        .toList();
  }

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
    search_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Modern Header
              _buildHeader(theme),

              // Search Bar
              _buildSearchBar(theme),

              // Content
              Expanded(
                child: StreamBuilder(
                  stream: discussionStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Apply advanced search algorithm
                    final questions = _performSearch(snapshot.data!.docs);

                    if (questions.isEmpty && _searchQuery.isNotEmpty) {
                      return _buildNoResultsState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final data =
                            questions[index].data() as Map<String, dynamic>;
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: displayCard(
                            title: data['Title'] ?? '',
                            description: data['Description'] ?? '',
                            tags: List<String>.from(data['Tags'] ?? []),
                            timestamp:
                                (data['Timestamp'] as Timestamp?)?.toDate() ??
                                    DateTime.now(),
                            uid: data['Uid'] ?? '',
                            docid: data['docId'] ?? '',
                            replies: [],
                          ),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => Get.to(add_discussion()),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
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
              Icons.forum_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discussions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Join the conversation',
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

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: TextField(
          controller: search_controller,
          onChanged: (val) => onSearch2(val),
          decoration: InputDecoration(
            hintText: 'Search discussions...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.primary,
            ),
            suffixIcon: search_controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => all(),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListShimmer(itemCount: 5),
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
              Icons.forum_outlined,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No discussions yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new discussion!',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.to(add_discussion()),
            icon: const Icon(Icons.add),
            label: const Text('Start Discussion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or tags',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class displayCard extends StatefulWidget {
  final String title;
  final String description;
  final List<String> tags;
  final String uid;
  final String docid;
  final DateTime timestamp;
  final List<String> replies; // Added to store replies as a list of reply IDs

  displayCard({
    super.key,
    required this.title,
    required this.description,
    required this.tags,
    required this.timestamp,
    required this.uid,
    required this.docid,
    required this.replies, // Initialize the replies list
  });

  @override
  displayCardState createState() => displayCardState();
}

class displayCardState extends State<displayCard> {
  Future<String?> _fetchUserName(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(widget.uid)
          .get();
      if (userDoc.exists) {
        return userDoc['Username'];
      } else {
        return 'Unknown User';
      }
    } catch (e) {
      print('Error fetching user data: $e');
      return 'Error';
    }
  }

  bool isLiked = false;
  bool isFetchingUserName = false;
  late Future<String?> _userNameFuture;

  @override
  void initState() {
    super.initState();
    print(widget.uid);
    _userNameFuture = _fetchUserName(widget.uid);
    print("object${_userNameFuture.toString()}");
    _fetchRepliesCount();
    // _checkIfLiked();
    // Access the parameters with widget.parameterName
  }

  int _repliesCount = 0;
  Future<void> _fetchRepliesCount() async {
    try {
      QuerySnapshot repliesSnapshot = await FirebaseFirestore.instance
          .collection('Discussions')
          .doc(widget.docid)
          .collection('Replies')
          .get();

      setState(() {
        _repliesCount = repliesSnapshot.size; // Set replies count
      });
    } catch (e) {
      print('Error fetching replies count: $e');
    }
  }

  Future<String?> _fetchUserProfileImage(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(widget.uid)
          .get();
      if (userDoc.exists) {
        return userDoc['profilePicture'];
      } else {
        return 'Unknown User';
      }
    } catch (e) {
      print('Error fetching user data: $e');
      return 'Error';
    }
  }

  Future<String?> _fetchUserXP(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(widget.uid)
          .get();
      if (userDoc.exists) {
        return userDoc['XP']?.toString();
      } else {
        return '100';
      }
    } catch (e) {
      print('Error fetching user data: $e');
      return 'Error';
    }
  }

  save(itemId) async {
    var usercredential = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection("User")
        .doc(usercredential?.uid)
        .update({
      'SavedDiscussion': FieldValue.arrayUnion([itemId])
    });

    Get.showSnackbar(GetSnackBar(
      title: "Success",
      message: "Discussion Saved",
      icon: Icon(
        Icons.bookmark,
        color: Colors.green,
      ),
      duration: Duration(seconds: 2),
    ));
  }

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Get.to(detail_discussion(
              docId: widget.docid,
              creatorId: widget.uid,
            ));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Row
                Row(
                  children: [
                    FutureBuilder<String?>(
                      future: _fetchUserProfileImage(widget.uid),
                      builder: (context, snapshot) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            foregroundImage:
                                snapshot.hasData && snapshot.data!.isNotEmpty
                                    ? NetworkImage(snapshot.data!)
                                    : const NetworkImage(
                                        'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                                      ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String?>(
                            future: _userNameFuture,
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.hasData
                                    ? snapshot.data!
                                    : 'Loading...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
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
                    FutureBuilder<String?>(
                      future: _fetchUserXP(widget.uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${snapshot.data} XP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
                // Footer
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_repliesCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.bookmark_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () => save(widget.docid),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

void _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('Could not launch $url');
  }
}

class SearchController extends GetxController {
  var searchText = ''.obs;

  void updateSearchText(String text) {
    searchText.value = text;
  }
}

/// Production-level search algorithm with fuzzy matching and relevance scoring
class SearchAlgorithm {
  /// Calculate relevance score for a discussion based on search query
  /// Returns a score between 0.0 and 1.0, where higher is more relevant
  static double calculateRelevance({
    required String query,
    required String title,
    required String description,
    required List<String> tags,
  }) {
    if (query.isEmpty) return 1.0;

    final queryLower = query.toLowerCase();
    final titleLower = title.toLowerCase();
    final descLower = description.toLowerCase();
    final queryTerms =
        queryLower.split(' ').where((t) => t.isNotEmpty).toList();

    double score = 0.0;

    // 1. Exact match in title (highest weight)
    if (titleLower.contains(queryLower)) {
      score += 100.0;
      // Bonus for match at start
      if (titleLower.startsWith(queryLower)) {
        score += 50.0;
      }
    }

    // 2. Exact match in tags (high weight)
    for (final tag in tags) {
      if (tag.toLowerCase() == queryLower) {
        score += 80.0;
      } else if (tag.toLowerCase().contains(queryLower)) {
        score += 40.0;
      }
    }

    // 3. Exact match in description (medium weight)
    if (descLower.contains(queryLower)) {
      score += 30.0;
    }

    // 4. Term-based matching (for multi-word queries)
    double termScore = 0.0;
    for (final term in queryTerms) {
      if (term.length < 2) continue;

      // Title matches
      if (titleLower.contains(term)) {
        termScore += 15.0;
      }

      // Tag matches
      for (final tag in tags) {
        if (tag.toLowerCase().contains(term)) {
          termScore += 10.0;
        }
      }

      // Description matches
      if (descLower.contains(term)) {
        termScore += 5.0;
      }
    }
    score += termScore;

    // 5. Fuzzy matching using Levenshtein distance
    final titleWords = titleLower.split(' ');
    final descWords =
        descLower.split(' ').take(20).toList(); // Limit desc words

    double fuzzyScore = 0.0;
    for (final term in queryTerms) {
      if (term.length < 3) continue;

      // Check title words
      for (final word in titleWords) {
        final distance = _levenshteinDistance(term, word);
        final similarity =
            1.0 - (distance / math.max(term.length, word.length));
        if (similarity > 0.7) {
          fuzzyScore += similarity * 10.0;
        }
      }

      // Check tag words
      for (final tag in tags) {
        final distance = _levenshteinDistance(term, tag.toLowerCase());
        final similarity = 1.0 - (distance / math.max(term.length, tag.length));
        if (similarity > 0.75) {
          fuzzyScore += similarity * 8.0;
        }
      }

      // Check description words (less weight)
      for (final word in descWords) {
        final distance = _levenshteinDistance(term, word);
        final similarity =
            1.0 - (distance / math.max(term.length, word.length));
        if (similarity > 0.8) {
          fuzzyScore += similarity * 2.0;
        }
      }
    }
    score += fuzzyScore;

    // 6. Normalize score to 0-1 range
    return math.min(1.0, score / 100.0);
  }

  /// Calculate Levenshtein distance between two strings (edit distance)
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    // Create a matrix
    List<List<int>> matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Fill the matrix
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(math.min);
      }
    }

    return matrix[len1][len2];
  }
}
