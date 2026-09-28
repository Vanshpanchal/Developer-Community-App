import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/add_discussion.dart';
import 'package:developer_community_app/detail_discussion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'models/poll_model.dart';
import 'widgets/poll_widgets.dart';
import 'utils/app_theme.dart';
import 'services/user_cache_service.dart';
import 'widgets/modern_widgets.dart';
import 'utils/app_snackbar.dart';
import 'utils/content_moderation.dart';
import 'dart:math' as math;
import 'widgets/scroll_fade_in.dart';
import 'utils/app_logger.dart';
import 'services/block_service.dart';
import 'widgets/linkified_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'utils/user_messages.dart';
import 'utils/date_format.dart';

class ongoing_discussion extends StatefulWidget {
  const ongoing_discussion({super.key});

  @override
  State<ongoing_discussion> createState() => _ongoing_discussionState();
}

class _ongoing_discussionState extends State<ongoing_discussion>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String imageUrl = '';
  TextEditingController search_controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final ScrollController _scrollController = ScrollController();
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Pages loaded on scroll, older than the live first page from the stream.
  final List<QueryDocumentSnapshot> _discussions = [];
  Timer? _searchDebounce;

  var discussionStream = FirebaseFirestore.instance
      .collection('Discussions')
      .where('Report', isEqualTo: false)
      .orderBy('Timestamp', descending: true)
      .limit(20)
      .snapshots();

  all() {
    setState(() {
      _discussions.clear();
      _lastDocument = null;
      _hasMore = true;
      _searchQuery = '';
      discussionStream = FirebaseFirestore.instance
          .collection('Discussions')
          .where('Report', isEqualTo: false)
          .orderBy('Timestamp', descending: true)
          .limit(20)
          .snapshots();
      // .snapshots();
    });
    search_controller.clear();
  }

  fetchuser() async {
    final box = GetStorage();
    final cached = box.read('userData');
    if (cached != null) {
      final data = cached as Map<String, dynamic>;
      setState(() {
        username = data['username'] ?? 'No name available';
        imageUrl = data['imageUrl'] ?? '';
      });
      return;
    }
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('User')
          .doc(user?.uid)
          .get();
      if (userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        final uname = data['Username'] ?? 'No name available';
        final img = data['profilePicture'] ?? '';
        setState(() {
          username = uname;
          imageUrl = img;
        });
        box.write('userData', {'username': uname, 'imageUrl': img});
      } else {
        setState(() {
          username = 'No name available';
        });
        box.write(
            'userData', {'username': 'No name available', 'imageUrl': ''});
      }
    }
  }

  String _searchQuery = '';

  onSearch2(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query.trim().toLowerCase();
      });
    });
  }

  // Memo for the ranked list, so rebuilds that don't change the inputs
  // (e.g. the loading indicator toggling) skip ranking and search.
  QuerySnapshot? _viewSnapshot;
  int _viewOlderCount = -1;
  String _viewQuery = '';
  Set<String>? _viewBlocked;
  List<QueryDocumentSnapshot> _view = const [];

  List<QueryDocumentSnapshot> _visibleDiscussions(QuerySnapshot snapshot) {
    final blocked = BlockService.instance.blockedIds.value;
    if (identical(snapshot, _viewSnapshot) &&
        _viewOlderCount == _discussions.length &&
        _viewQuery == _searchQuery &&
        identical(blocked, _viewBlocked)) {
      return _view;
    }
    _viewSnapshot = snapshot;
    _viewOlderCount = _discussions.length;
    _viewQuery = _searchQuery;
    _viewBlocked = blocked;
    return _view = _performSearch(_mergeWithLoadedPages(snapshot.docs)
        .where((doc) => !blocked.contains(
            (doc.data() as Map<String, dynamic>)['Uid'] as String?))
        .toList());
  }

  /// Live first page plus older pages, de-duplicated and in Timestamp order.
  /// Also moves the pagination cursor to the oldest loaded document.
  List<QueryDocumentSnapshot> _mergeWithLoadedPages(
      List<QueryDocumentSnapshot> streamDocs) {
    final seen = <String>{};
    final merged = <QueryDocumentSnapshot>[
      for (final doc in [...streamDocs, ..._discussions])
        if (seen.add(doc.id)) doc,
    ];
    DateTime timeOf(QueryDocumentSnapshot doc) =>
        ((doc.data() as Map<String, dynamic>)['Timestamp'] as Timestamp?)
            ?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    merged.sort((a, b) => timeOf(b).compareTo(timeOf(a)));
    if (merged.isNotEmpty) _lastDocument = merged.last;
    if (_discussions.isEmpty) _hasMore = streamDocs.length >= _limit;
    return merged;
  }

  List<QueryDocumentSnapshot> _performSearch(List<QueryDocumentSnapshot> docs) {
    final rankedDocs = _rankDiscussions(docs);
    if (_searchQuery.isEmpty) return rankedDocs;

    // Calculate relevance scores for each document
    final scoredDocs = rankedDocs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final relevance = SearchAlgorithm.calculateRelevance(
            query: _searchQuery,
            title: data['Title']?.toString() ?? '',
            description: data['Description']?.toString() ?? '',
            tags: List<String>.from(data['Tags'] ?? []),
          );
          final score = (relevance * 100) +
              ContentModerationService.calculateFeedScore(data);
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

  List<QueryDocumentSnapshot> _rankDiscussions(
      List<QueryDocumentSnapshot> docs) {
    final rankedDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['contentStatus']?.toString() != 'blocked';
    }).toList();

    // Score each discussion once rather than on every comparison.
    final scores = {
      for (final doc in rankedDocs)
        doc.id: ContentModerationService.calculateFeedScore(
            doc.data() as Map<String, dynamic>),
    };
    rankedDocs.sort((a, b) {
      final leftData = a.data() as Map<String, dynamic>;
      final rightData = b.data() as Map<String, dynamic>;

      final scoreComparison = scores[b.id]!.compareTo(scores[a.id]!);
      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final leftTime = (leftData['Timestamp'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime = (rightData['Timestamp'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return rightTime.compareTo(leftTime);
    });

    return rankedDocs;
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

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
    BlockService.instance.blockedIds.addListener(_onBlockListChanged);
  }

  void _onBlockListChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    BlockService.instance.blockedIds.removeListener(_onBlockListChanged);
    _searchDebounce?.cancel();
    _animationController.dispose();
    search_controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;
    if (_searchQuery.isNotEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextBatch = await FirebaseFirestore.instance
          .collection('Discussions')
          .where('Report', isEqualTo: false)
          .orderBy('Timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_limit)
          .get();

      if (!mounted) return;
      setState(() {
        _discussions.addAll(nextBatch.docs);
        if (nextBatch.docs.isNotEmpty) _lastDocument = nextBatch.docs.last;
        _hasMore = nextBatch.docs.length == _limit;
      });
    } catch (e) {
      AppLogger.error('Error loading more discussions', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
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
                      return _buildErrorState(userMessageFor(snapshot.error!,
                          fallback: "Couldn't load discussions."));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Render the live first page plus pages loaded on scroll.
                    final questions = _visibleDiscussions(snapshot.data!);

                    if (questions.isEmpty && _searchQuery.isNotEmpty) {
                      return _buildNoResultsState();
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        all(); // Re-fetches the initial stream
                        await Future.delayed(const Duration(milliseconds: 800));
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: questions.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == questions.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final data =
                              questions[index].data() as Map<String, dynamic>;
                          final rawPollData = data['poll'];
                          final pollMap = rawPollData is Map
                              ? Map<String, dynamic>.from(rawPollData)
                              : null;
                          return ScrollFadeIn(
                            key: ValueKey(questions[index].id),
                            child: displayCard(
                              title: data['Title'] ?? '',
                              description: data['Description'] ?? '',
                              tags: List<String>.from(data['Tags'] ?? []),
                              timestamp:
                                  (data['Timestamp'] as Timestamp?)?.toDate() ??
                                      DateTime.now(),
                              uid: data['Uid'] ?? '',
                              docid: questions[index].id,
                              replies: [],
                              hasPoll: data['hasPoll'] == true,
                              pollData: pollMap,
                            ),
                          );
                        },
                      ),
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
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: search_controller,
          onChanged: (val) => onSearch2(val),
          decoration: InputDecoration(
            hintText: 'Search discussions, tags, topics...',
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

  Widget _buildErrorState(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: all,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
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
  final Map<String, dynamic>? pollData; // Poll data
  final bool hasPoll; // Whether discussion has a poll

  const displayCard({
    super.key,
    required this.title,
    required this.description,
    required this.tags,
    required this.timestamp,
    required this.uid,
    required this.docid,
    required this.replies, // Initialize the replies list
    this.pollData,
    this.hasPoll = false,
  });

  @override
  displayCardState createState() => displayCardState();
}

class displayCardState extends State<displayCard> {


  bool isLiked = false;
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = UserCacheService.instance.getUserData(widget.uid);
    _fetchRepliesCount();
  }

  @override
  void didUpdateWidget(covariant displayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _userDataFuture = UserCacheService.instance.getUserData(widget.uid);
    }
    if (oldWidget.docid != widget.docid) _fetchRepliesCount();
  }

  int _repliesCount = 0;
  Future<void> _fetchRepliesCount() async {
    try {
      // Aggregate count: one billed read instead of downloading every reply.
      final countSnapshot = await FirebaseFirestore.instance
          .collection('Discussions')
          .doc(widget.docid)
          .collection('Replies')
          .count()
          .get();

      if (!mounted) return;
      setState(() {
        _repliesCount = countSnapshot.count ?? 0;
      });
    } catch (e) {
      AppLogger.warning('Error fetching replies count: $e');
    }
  }



  save(itemId) async {
    try {
      var usercredential = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection("User")
          .doc(usercredential?.uid)
          .update({
        'SavedDiscussion': FieldValue.arrayUnion([itemId])
      });
      AppSnackbar.success('Discussion Saved', title: 'Success');
    } catch (e) {
      AppSnackbar.error('Failed to save discussion');
    }
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
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            foregroundImage: hasImage
                                    ? CachedNetworkImageProvider(imageUrl)
                                    : const AssetImage('assets/images/default_avatar.png'),
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
                LinkifiedText(
                  widget.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Poll Display (if exists)
                if (widget.hasPoll && widget.pollData != null) ...[
                  const SizedBox(height: 12),
                  PollDisplayWidget(
                    poll: Poll.fromMap(widget.pollData!),
                    parentId: widget.docid,
                    parentCollection: 'Discussions',
                    onVoted: () {
                      // Refresh card to update results
                      setState(() {});
                    },
                    canDelete: false, // Don't allow deletion from card
                  ),
                ],

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
                      tooltip: 'Save discussion',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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

  String _formatDate(DateTime date) => formatRelativeDate(date);
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
