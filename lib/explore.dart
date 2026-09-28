import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/addpost.dart';
import 'package:developer_community_app/chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'ai_service.dart';
import 'portfolio.dart';
import 'services/gamification_service.dart';
import 'services/firebase_cache_service.dart';
import 'models/gamification_models.dart';
import 'utils/app_theme.dart';
import 'utils/app_snackbar.dart';
import 'utils/app_logger.dart';
import 'utils/content_moderation.dart';
import 'services/user_cache_service.dart';
import 'widgets/modern_widgets.dart';
import 'dart:async';
import 'dart:math' as math;
import 'widgets/scroll_fade_in.dart';
import 'services/account_service.dart';
import 'services/block_service.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/linkified_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'utils/date_format.dart';

class explore extends StatefulWidget {
  const explore({super.key});

  @override
  exploreState createState() => exploreState();
}

class exploreState extends State<explore>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final user = FirebaseAuth.instance.currentUser;
  final _cacheService = FirebaseCacheService();
  TextEditingController search_controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final ScrollController _scrollController = ScrollController();
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;

  // Source data, kept in Firestore order (Timestamp desc). `_headPosts` is the
  // live first page from the stream; `_olderPosts` are pages loaded on scroll.
  List<Map<String, dynamic>> _headPosts = [];
  List<Map<String, dynamic>> _olderPosts = [];
  // Derived views, recomputed only when the source or the search query changes.
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _visiblePosts = [];
  // Cursor: id of the oldest loaded post (by Timestamp, not by feed rank).
  String? _lastDocumentId;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _savedSubscription;
  Set<String> _savedIds = {};
  Timer? _searchDebounce;

  String username = '';
  String imageUrl = '';

  late Stream<List<Map<String, dynamic>>> _postsStream;

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

    _setupFeed();
    _listenToSaved();
    BlockService.instance.blockedIds.addListener(_onBlockListChanged);

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    BlockService.instance.blockedIds.removeListener(_onBlockListChanged);
    _streamSubscription?.cancel();
    _savedSubscription?.cancel();
    _searchDebounce?.cancel();
    _animationController.dispose();
    search_controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Streams the viewer's saved ids once, instead of one read per card.
  void _listenToSaved() {
    final uid = user?.uid;
    if (uid == null) return;
    _savedSubscription = FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      setState(() {
        _savedIds = Set<String>.from(doc.data()?['Saved'] ?? const []);
      });
    }, onError: (e) => AppLogger.warning('Saved ids stream error: $e'));
  }

  static Map<String, dynamic> _withId(Map<String, dynamic> post) {
    final id = post['id'] ?? post['docId'];
    return {...post, 'id': id, 'docId': id};
  }

  static DateTime _timeOf(Map<String, dynamic> post) {
    final ts = post['Timestamp'];
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime(0);
    return DateTime(0);
  }

  void _onBlockListChanged() {
    if (mounted) setState(_recomputeViews);
  }

  /// Rebuilds the ranked and searched views from the source lists.
  void _recomputeViews() {
    final seen = <String>{};
    final source = <Map<String, dynamic>>[];
    for (final post in [..._headPosts, ..._olderPosts]) {
      final id = post['id'] as String?;
      if (id != null && seen.add(id)) source.add(post);
    }
    source.sort((a, b) => _timeOf(b).compareTo(_timeOf(a)));
    // The cursor uses the unfiltered list so paging is unaffected by blocks.
    _lastDocumentId = source.isNotEmpty ? source.last['id'] as String? : null;
    final blocks = BlockService.instance;
    _posts = _rankPosts(source
        .where((post) => !blocks.isBlocked(post['Uid'] as String?))
        .toList());
    _visiblePosts = _performSearch(_posts);
  }

  void _setupFeed() {
    _streamSubscription?.cancel();

    // Attempt to load from cache first
    try {
      final cachedPosts = _cacheService.getCachedData(
        collectionName: 'Explore',
        where: {'Report': false},
        orderBy: 'Timestamp',
        descending: true,
        limit: _limit,
      );

      if (cachedPosts != null && cachedPosts.isNotEmpty) {
        setState(() {
          _headPosts = cachedPosts.map(_withId).toList();
          _recomputeViews();
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      AppLogger.warning('Error loading cached posts: $e');
    }

    _postsStream = _cacheService.listenToCollection(
      collectionName: 'Explore',
      where: {'Report': false},
      orderBy: 'Timestamp',
      descending: true,
      limit: _limit,
    );

    _streamSubscription = _postsStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _hasError = false;
        // Stream events only replace the live first page; older pages that
        // were loaded on scroll are kept.
        _headPosts = data.map(_withId).toList();
        if (_olderPosts.isEmpty) _hasMore = data.length >= _limit;
        _recomputeViews();
      });
    }, onError: (error) {
      AppLogger.error('Explore stream error', error);
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _hasError = _posts.isEmpty;
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDocumentId == null) return;
    if (_searchQuery.isNotEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final lastDoc = await FirebaseFirestore.instance
          .collection('Explore')
          .doc(_lastDocumentId)
          .get();
      if (!lastDoc.exists) {
        if (mounted) setState(() => _hasMore = false);
        return;
      }
      final nextBatch = await FirebaseFirestore.instance
          .collection('Explore')
          .where('Report', isEqualTo: false)
          .orderBy('Timestamp', descending: true)
          .startAfterDocument(lastDoc)
          .limit(_limit)
          .get();

      if (!mounted) return;
      final newData = nextBatch.docs
          .map((doc) => _withId({...doc.data(), 'id': doc.id}))
          .toList();
      setState(() {
        _olderPosts = [..._olderPosts, ...newData];
        _hasMore = newData.length == _limit;
        _recomputeViews();
      });
    } catch (e) {
      AppLogger.error('Error loading more posts', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void openbottmsheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (ctx) => addpost());
  }

  String _searchQuery = '';

  onSearch2(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query.trim().toLowerCase();
        _visiblePosts = _performSearch(_posts);
      });
    });
  }

  List<Map<String, dynamic>> _performSearch(
      List<Map<String, dynamic>> rankedDocs) {
    if (_searchQuery.isEmpty) return rankedDocs;

    // Perform search on the current docs

    // Calculate relevance scores for each document
    final scoredDocs = rankedDocs
        .map((doc) {
          final data = doc;
          final relevance = ExploreSearchAlgorithm.calculateRelevance(
            query: _searchQuery,
            title: data['Title']?.toString() ?? '',
            description: data['Description']?.toString() ?? '',
            tags: List<String>.from(data['Tags'] ?? []),
            code: data['code']?.toString() ?? '',
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
        .map((item) => item['doc']! as Map<String, dynamic>)
        .toList();
  }

  List<Map<String, dynamic>> _rankPosts(List<Map<String, dynamic>> posts) {
    // Deduplicate by 'id' or 'docId'
    final seenIds = <String>{};
    final uniquePosts = <Map<String, dynamic>>[];

    for (final post in posts) {
      final id = post['id'] ?? post['docId'];
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        uniquePosts.add(post);
      }
    }

    final rankedPosts = uniquePosts
        .where((post) =>
            post['contentStatus']?.toString() != 'blocked' &&
            post['Report'] != true)
        .toList();

    // Score each post once rather than on every comparison.
    final scores = {
      for (final post in rankedPosts)
        post['id']: ContentModerationService.calculateFeedScore(post),
    };
    rankedPosts.sort((a, b) {
      final scoreComparison =
          (scores[b['id']] ?? 0).compareTo(scores[a['id']] ?? 0);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return _timeOf(b).compareTo(_timeOf(a));
    });

    return rankedPosts;
  }

  all() {
    setState(() {
      _headPosts = [];
      _olderPosts = [];
      _searchQuery = '';
      _hasMore = true;
      _recomputeViews();
    });
    _setupFeed();
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

  Future<void> _refreshPosts() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _cacheService
          .clearCache('Explore_Report_false_order_Timestamp_limit_20');

      final refreshedBatch = await FirebaseFirestore.instance
          .collection('Explore')
          .where('Report', isEqualTo: false)
          .orderBy('Timestamp', descending: true)
          .limit(_limit)
          .get();

      if (!mounted) return;

      final refreshedPosts = refreshedBatch.docs
          .map((doc) => _withId({...doc.data(), 'id': doc.id}))
          .toList();

      setState(() {
        _headPosts = refreshedPosts;
        _olderPosts = [];
        _hasMore = refreshedPosts.length == _limit;
        _hasError = false;
        _recomputeViews();
        _isLoadingMore = false;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.error('Failed to refresh posts.', title: 'Refresh Error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
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
              // Modern App Bar
              _buildModernAppBar(theme),

              // Search Bar
              _buildSearchBar(theme),

              // Content
              Expanded(
                child: Builder(builder: (context) {
                  if (_isInitialLoading) {
                    return _buildLoadingState();
                  }

                  final questions = _visiblePosts;

                  if (_hasError) {
                    return _buildErrorState();
                  }

                  if (questions.isEmpty) {
                    if (_searchQuery.isNotEmpty) {
                      return _buildNoResultsState();
                    }
                    if (_posts.isEmpty) {
                      return _buildEmptyState();
                    }
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshPosts,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: questions.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == questions.length) {
                          return const SizedBox(
                            height: 60,
                            child: Center(
                              child: Opacity(
                                opacity: 0.5,
                                child:
                                    Text('•', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                          );
                        }

                        final data = questions[index];
                        return ScrollFadeIn(
                          delay: Duration(
                              milliseconds: index < 5 ? index * 80 : 0),
                          child: QuestionCard(
                            key: ValueKey(data['id']),
                            likes: List<String>.from(data['likes'] ?? const []),
                            isSaved: _savedIds.contains(data['id']),
                            title: data['Title'] ?? '',
                            description: data['Description'] ?? '',
                            tags: List<String>.from(data['Tags'] ?? []),
                            votes: data['likescount'] ?? 0,
                            answers: data['answers'] ?? 0,
                            timestamp:
                                (data['Timestamp'] as Timestamp?)?.toDate() ??
                                    DateTime.now(),
                            code: data['code'] ?? '',
                            uid: data['Uid'] ?? '',
                            docid: data['id'] ?? '',
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActions(theme),
    );
  }

  Widget _buildModernAppBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Logo and Title
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
              Icons.code_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DevSphere',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Explore & Learn',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Profile Avatar
          Semantics(
            button: true,
            label: 'Open your portfolio',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                if (user != null) {
                  Get.to(DeveloperPortfolioPage(userId: user!.uid));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: imageUrl.isEmpty
                        ? Icon(Icons.person, color: theme.colorScheme.primary)
                        : null,
                  ),
                ),
              ),
            ),
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
            hintText: 'Search posts, tags, topics...',
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

  Widget _buildErrorState() {
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
              "Couldn't load posts",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refreshPosts,
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
              Icons.article_outlined,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.to(addpost()),
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
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

  Widget _buildFloatingActions(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Repo Analyzer FAB
        // FloatingActionButton.small(
        //   onPressed: () => Get.to(RepoAnalyzerScreen()),
        //   backgroundColor: AppTheme.accentColor,
        //   heroTag: "fab_repo",
        //   elevation: 4,
        //   child: const Icon(Icons.analytics_rounded,
        //       color: Colors.white, size: 20),
        // ),
        // const SizedBox(height: 12),
        // AI Chat FAB
        FloatingActionButton.small(
          onPressed: () => Get.to(ChatScreen1()),
          backgroundColor: AppTheme.secondaryColor,
          heroTag: "fab1",
          elevation: 4,
          child: const Icon(Icons.smart_toy_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(height: 12),
        // Add Post FAB
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                blurRadius: 12,
                // offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: FloatingActionButton(
              onPressed: () => Get.to(addpost()),
              backgroundColor: Colors.transparent,
              elevation: 0,
              heroTag: "fab2",
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class UserInfoShimmer extends StatelessWidget {
  const UserInfoShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ShimmerLoading(width: 40, height: 40, borderRadius: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            ShimmerLoading(width: 100, height: 14),
            SizedBox(height: 6),
            ShimmerLoading(width: 60, height: 12),
          ],
        ),
        const Spacer(),
        const ShimmerLoading(width: 50, height: 20, borderRadius: 10),
      ],
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

  /// Uids that liked the post, as already loaded by the feed. When null the
  /// card fetches the like state itself.
  final List<String>? likes;

  /// Whether the viewer has bookmarked the post. When null the card fetches it.
  final bool? isSaved;

  const QuestionCard({
    super.key,
    this.likes,
    this.isSaved,
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
  bool _showComplexity = false;
  String? _complexityResult;
  bool _complexityLoading = false;
  bool _showFullCode = false;
  bool _showFullDescription = false; // For expandable description
  final _gamificationService = GamificationService();

  bool _likeInFlight = false;
  bool _saveInFlight = false;

  @override
  void initState() {
    super.initState();
    _userDataFuture = UserCacheService.instance.getUserData(widget.uid);
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _userDataFuture = UserCacheService.instance.getUserData(widget.uid);
    }
    if (oldWidget.docid != widget.docid ||
        oldWidget.isSaved != widget.isSaved ||
        !listEquals(oldWidget.likes, widget.likes)) {
      _syncFromWidget();
    }
  }

  /// Takes like/saved state from the parent when it provides it, so a feed
  /// page does not cost extra reads per card.
  void _syncFromWidget() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.likes != null) {
      if (!_likeInFlight) isLiked = widget.likes!.contains(uid);
    } else {
      _checkIfLiked();
    }
    if (widget.isSaved != null) {
      if (!_saveInFlight) isSaved = widget.isSaved!;
    } else {
      _checkIfSaved();
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final saved = List<String>.from(userDoc.data()?['Saved'] ?? []);
        if (mounted) {
          setState(() {
            isSaved = saved.contains(widget.docid);
          });
        }
      }
    } catch (e) {
      AppLogger.warning('Error checking saved status: $e');
    }
  }

  Future<void> _handleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _likeInFlight) return;

    final startLiked = isLiked;
    setState(() {
      _likeInFlight = true;
      isLiked = !startLiked;
    });
    HapticFeedback.lightImpact();

    try {
      final questionRef =
          FirebaseFirestore.instance.collection('Explore').doc(widget.docid);

      // Read and write in one transaction so rapid taps or concurrent likes
      // cannot drift `likescount` away from `likes`.
      final nowLiked =
          await FirebaseFirestore.instance.runTransaction<bool?>((tx) async {
        final snap = await tx.get(questionRef);
        if (!snap.exists) return null;
        final likes = List<String>.from(snap.data()?['likes'] ?? const []);
        final liked = likes.contains(currentUser.uid);
        tx.update(questionRef, {
          'likes': liked
              ? FieldValue.arrayRemove([currentUser.uid])
              : FieldValue.arrayUnion([currentUser.uid]),
          'likescount': FieldValue.increment(liked ? -1 : 1),
        });
        return !liked;
      });

      if (!mounted) return;
      if (nowLiked == null) {
        setState(() => isLiked = startLiked);
        return;
      }
      setState(() => isLiked = nowLiked);

      if (nowLiked) {
        // Gamification rewards (background)
        _gamificationService.awardXp(XpAction.giveLike);
        _gamificationService.incrementCounter('likesGiven');

        if (widget.uid != currentUser.uid) {
          _gamificationService.awardXp(XpAction.receiveLike,
              targetUserId: widget.uid);
        }
      }
    } catch (e) {
      AppLogger.error('Error handling like', e);
      if (mounted) setState(() => isLiked = startLiked);
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  Future<void> _handleSave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _saveInFlight) return;

    // Optimistic Update
    final startSaved = isSaved;
    setState(() {
      _saveInFlight = true;
      isSaved = !isSaved;
    });

    HapticFeedback.lightImpact();

    try {
      final userRef =
          FirebaseFirestore.instance.collection("User").doc(user.uid);

      if (startSaved) {
        // Was saved, remove it
        await userRef.update({
          'Saved': FieldValue.arrayRemove([widget.docid])
        });
      } else {
        // Was not saved, add it
        await userRef.update({
          'Saved': FieldValue.arrayUnion([widget.docid])
        });
      }
    } catch (e) {
      AppLogger.error('Error toggling save', e);
      // Revert
      if (mounted) {
        setState(() {
          isSaved = startSaved;
        });
        AppSnackbar.error('Failed to update bookmark');
      }
    } finally {
      if (mounted) setState(() => _saveInFlight = false);
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      DocumentReference questionRef =
          FirebaseFirestore.instance.collection('Explore').doc(widget.docid);
      DocumentSnapshot questionDoc = await questionRef.get();
      if (questionDoc.exists) {
        var likes = questionDoc['likes'];
        if (likes is List) {
          if (mounted) {
            setState(() {
              isLiked = likes.contains(FirebaseAuth.instance.currentUser?.uid);
            });
          }
        } else {
          if (mounted) {
            setState(() {
              isLiked = false;
            });
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error checking like status: $e');
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Row
            _buildUserInfoRow(theme),
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

            // Description with Read More functionality
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinkifiedText(
                  widget.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: _showFullDescription ? null : 3,
                  overflow: _showFullDescription
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                if (widget.description.length >
                    150) // Show button if description is long
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFullDescription = !_showFullDescription;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _showFullDescription ? 'Show less' : 'Read more',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
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
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 24,
                    color: isSaved
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _handleSave,
                  tooltip: isSaved ? 'Remove bookmark' : 'Save post',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
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

  Widget _buildUserInfoRow(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const UserInfoShimmer();
        }

        final userData = snapshot.data ?? {};
        final imageUrl = userData['profilePicture'] as String?;
        final hasImage = imageUrl != null && imageUrl.isNotEmpty;
        final userName = userData['Username']?.toString() ?? 'Unknown';
        final userXP = userData['XP']?.toString() ?? '100';

        return Row(
          children: [
            // Profile Image
            Semantics(
              button: true,
              label: "Open $userName's profile",
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DeveloperPortfolioPage(userId: widget.uid),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    backgroundImage: hasImage
                        ? CachedNetworkImageProvider(imageUrl)
                        : const AssetImage('assets/images/default_avatar.png'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Username
            Expanded(
              child: Semantics(
                button: true,
                hint: 'Opens profile',
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DeveloperPortfolioPage(userId: widget.uid),
                      ),
                    );
                  },
                  child: Text(
                    userName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // XP Badge
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
            _buildPostMenu(userName),
          ],
        );
      },
    );
  }

  Widget _buildPostMenu(String userName) {
    final isOwn = FirebaseAuth.instance.currentUser?.uid == widget.uid;
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) async {
        if (value == 'delete') {
          final confirm = await AppDialogs.showConfirmation(
            context,
            title: 'Delete post',
            message: 'This permanently deletes your post.',
            confirmText: 'Delete',
            cancelText: 'Cancel',
          );
          if (confirm != true) return;
          try {
            await AccountService.instance.deletePost(widget.docid);
            AppSnackbar.success('Post deleted');
          } catch (e) {
            AppLogger.error('Failed to delete post', e);
            AppSnackbar.error('Could not delete the post. Please try again.');
          }
        } else if (value == 'block') {
          final confirm = await AppDialogs.showConfirmation(
            context,
            title: 'Block $userName?',
            message:
                "You won't see their posts, discussions or replies. You can unblock them from your profile.",
            confirmText: 'Block',
            cancelText: 'Cancel',
          );
          if (confirm != true) return;
          try {
            await BlockService.instance.block(widget.uid);
            AppSnackbar.success('$userName blocked');
          } catch (e) {
            AppLogger.error('Failed to block user', e);
            AppSnackbar.error('Could not block this user. Please try again.');
          }
        }
      },
      itemBuilder: (_) => [
        if (isOwn)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Delete post'),
              contentPadding: EdgeInsets.zero,
            ),
          )
        else
          const PopupMenuItem(
            value: 'block',
            child: ListTile(
              leading: Icon(Icons.block_rounded),
              title: Text('Block user'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
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
                    AppSnackbar.success(
                      'Code copied to clipboard',
                      title: 'Copied!',
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
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
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
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
      return const ShimmerLoading(
        width: 14,
        height: 14,
        borderRadius: 7,
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
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      visualDensity: VisualDensity.compact,
      tooltip: _showComplexity ? 'Hide analysis' : 'Analyze complexity',
      color: theme.colorScheme.primary,
    );
  }

  // ignore: unused_element
  Widget _buildTags(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ignore: unused_element
  Widget _buildActionsRow(ThemeData theme) {
    return Row(
      children: [
        // Like Button
        _buildActionButton(
          icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
          label: '${widget.votes}',
          isActive: isLiked,
          onTap: _handleLike,
          theme: theme,
        ),
        const SizedBox(width: 16),

        // Save Button
        _buildActionButton(
          icon: Icons.bookmark_outline_rounded,
          label: 'Save',
          onTap: _handleSave,
          theme: theme,
        ),

        const Spacer(),

        // Timestamp
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(widget.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
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
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? AppTheme.primaryColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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

/// Production-level search algorithm for explore posts with code search support
class ExploreSearchAlgorithm {
  /// Calculate relevance score for a post based on search query
  static double calculateRelevance({
    required String query,
    required String title,
    required String description,
    required List<String> tags,
    required String code,
  }) {
    if (query.isEmpty) return 1.0;

    final queryLower = query.toLowerCase();
    final titleLower = title.toLowerCase();
    final descLower = description.toLowerCase();
    final codeLower = code.toLowerCase();
    final queryTerms =
        queryLower.split(' ').where((t) => t.isNotEmpty).toList();

    double score = 0.0;

    // 1. Exact match in title (highest weight)
    if (titleLower.contains(queryLower)) {
      score += 100.0;
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

    // 3. Exact match in code (medium-high weight)
    if (code.isNotEmpty && codeLower.contains(queryLower)) {
      score += 50.0;
    }

    // 4. Exact match in description (medium weight)
    if (descLower.contains(queryLower)) {
      score += 30.0;
    }

    // 5. Term-based matching (for multi-word queries)
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

      // Code matches
      if (code.isNotEmpty && codeLower.contains(term)) {
        termScore += 8.0;
      }

      // Description matches
      if (descLower.contains(term)) {
        termScore += 5.0;
      }
    }
    score += termScore;

    // 6. Fuzzy matching using Levenshtein distance
    final titleWords = titleLower.split(' ');
    final descWords = descLower.split(' ').take(20).toList();
    final codeWords = code.isNotEmpty
        ? codeLower.split(RegExp(r'[\s\n;{}()[\]]')).take(30).toList()
        : [];

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

      // Check code words (programming terms)
      for (final word in codeWords) {
        if (word.length < 2) continue;
        final distance = _levenshteinDistance(term, word);
        final similarity =
            1.0 - (distance / math.max(term.length, word.length));
        if (similarity > 0.8) {
          fuzzyScore += similarity * 6.0;
        }
      }

      // Check description words
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

    // 7. Normalize score to 0-1 range
    return math.min(1.0, score / 100.0);
  }

  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    List<List<int>> matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }

    return matrix[len1][len2];
  }
}
