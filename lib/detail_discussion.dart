import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/attachcode.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_service.dart';
import 'services/gamification_service.dart';
import 'models/gamification_models.dart';
import 'models/poll_model.dart';
import 'utils/app_theme.dart';
import 'widgets/modern_widgets.dart';
import 'widgets/poll_widgets.dart';
import 'utils/app_snackbar.dart';
import 'utils/content_moderation.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/scroll_fade_in.dart';
import 'services/user_cache_service.dart';

class detail_discussion extends StatefulWidget {
  final String docId;
  final String creatorId;

  const detail_discussion(
      {super.key, Key? keys, required this.docId, required this.creatorId});

  @override
  State<detail_discussion> createState() => _detail_discussionState();
}

class _detail_discussionState extends State<detail_discussion> {
  final _replyController = TextEditingController();
  final _nestedReplyController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;
  bool _summaryLoading = false;
  // ignore: unused_field
  String? _threadSummary;
   final _gamificationService = GamificationService();
  bool _isLoading = false;
  bool _isTopSectionCollapsed = true;
  bool _nestedReplyLoading = false;
  late final Stream<DocumentSnapshot> _discussionStream;
  late final Stream<QuerySnapshot> _repliesStream;

  final ValueNotifier<String?> _activeReplyId = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _activeReplyUserName =
      ValueNotifier<String?>(null);

  bool _isUnsafeContent(Map<String, dynamic> data) {
    final contentStatus = data['contentStatus']?.toString().toLowerCase();
    return data['Report'] == true || contentStatus == 'blocked';
  }

  @override
  void initState() {
    super.initState();
    _discussionStream = FirebaseFirestore.instance
        .collection('Discussions')
        .doc(widget.docId)
        .snapshots();
    _repliesStream = FirebaseFirestore.instance
        .collection('Discussions')
        .doc(widget.docId)
        .collection('Replies')
        .orderBy('timestamp')
        .snapshots();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _nestedReplyController.dispose();
    _activeReplyId.dispose();
    _activeReplyUserName.dispose();
    super.dispose();
  }

  Future<void> updateXP2(String uid, int points) async {
    try {
      // Fetch the current XP value as a String
      final userDoc =
          await FirebaseFirestore.instance.collection('User').doc(uid).get();

      if (userDoc.exists) {
        // Get the current XP value (could be int or String)
        String currentXPString =
            userDoc.data()?['XP']?.toString() ?? '0'; // Convert to String
        int currentXP = int.tryParse(currentXPString) ?? 0; // Parse to int

        // Update XP (add or subtract points)
        int updatedXP = currentXP - points;

        // Save the updated XP back to Firestore as an int
        await FirebaseFirestore.instance.collection('User').doc(uid).update({
          'XP': updatedXP,
          'lastXpUpdate': FieldValue.serverTimestamp(),
        });

        // Log XP history for sync
        await FirebaseFirestore.instance
            .collection('User')
            .doc(uid)
            .collection('xp_history')
            .add({
          'action': 'helpfulAnswerRemoved',
          'xp': -points,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Accepted answer deleted',
        });

        print('XP updated successfully to $updatedXP!');
      } else {
        print('User document not found.');
      }
    } catch (e) {
      print('Error updating XP: $e');
    }
  }

  Future<String?> _fetchUserXP(String uid) async {
    try {
      final userData = await UserCacheService.instance.getUserData(uid);
      return userData['XP']?.toString() ?? '100';
    } catch (e) {
      print('Error fetching user data: $e');
      return 'Error';
    }
  }

  Future<String?> _fetchUserProfileImage(String uid) async {
    try {
      final userData = await UserCacheService.instance.getUserData(uid);
      return userData['profilePicture'] as String?;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<int> getRepliesCount() async {
    try {
      // Fetch the Replies collection for a specific document
      QuerySnapshot repliesSnapshot = await FirebaseFirestore.instance
          .collection('Discussions') // Specify the parent collection
          .doc(widget.docId) // Reference the specific document
          .collection('Replies') // Specify the Replies collection
          .get();

      // Return the number of documents in the Replies collection
      return repliesSnapshot.size.toInt();
    } catch (e) {
      print('Error getting replies count: $e');
      return 0; // Return 0 in case of an error
    }
  }

  Future<void> addReply() async {
    final replyText = _replyController.text.trim();
    setState(() => _isLoading = true);

    final moderation = await ContentModerationService.moderateReply(replyText);
    if (moderation.shouldReject) {
      if (mounted) setState(() => _isLoading = false);
      AppSnackbar.error(moderation.userMessage, title: 'Reply Rejected');
      return;
    }

    try {
      // Fetch the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      // Fetch user details from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();

      print(user.uid);
      if (userDoc.exists) {
        // Get username and profile picture, fallback if not available
        final username = userDoc.data()?['Username'] ?? 'Anonymous';
        final imageUrl = userDoc.data()?['profilePicture'] ?? '';

        // Add reply to Firestore

        final replyDocRef = FirebaseFirestore.instance
            .collection('Discussions')
            .doc(widget.docId)
            .collection('Replies')
            .doc();
        await replyDocRef.set({
          'replyId': replyDocRef.id,
          'reply': replyText,
          'user_name': username,
          'profilePicture': imageUrl,
          'uid': FirebaseAuth.instance.currentUser?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'code': "",
          'accepted': false,
          'likes': [],
          'qualityScore': moderation.qualityScore,
          'contentStatus': moderation.statusKey,
          'deprioritizeInFeed': moderation.shouldDeprioritize,
          'moderationFlags': moderation.flags,
          'moderationSource': moderation.source,
        });

        // Clear the reply text field
        _replyController.clear();

        // Award XP for posting reply
        await _gamificationService.awardXp(XpAction.postReply);
        await _gamificationService.incrementCounter('repliesCount');
        await _gamificationService.recordActivity();

        // Show success message
        AppSnackbar.success(
            'Reply added successfully! +${XpAction.postReply.defaultXp} XP');
      } else {
        // Handle case where user document does not exist
        throw Exception('User document not found in Firestore.');
      }
    } catch (e) {
      // Print error to console
      print('Error adding reply: $e');

      // Show error message to the user
      AppSnackbar.error('Failed to add reply: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Toggle like on a reply
  Future<void> _toggleLike(String replyId, List<dynamic> currentLikes) async {
    final uid = user?.uid;
    if (uid == null) return;
    final replyRef = FirebaseFirestore.instance
        .collection('Discussions')
        .doc(widget.docId)
        .collection('Replies')
        .doc(replyId);
    if (currentLikes.contains(uid)) {
      await replyRef.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await replyRef.update({
        'likes': FieldValue.arrayUnion([uid])
      });
    }
  }

  /// Toggle like on a *nested* reply
  Future<void> _toggleNestedLike(String parentReplyId, String subReplyId,
      List<dynamic> currentLikes) async {
    final uid = user?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('Discussions')
        .doc(widget.docId)
        .collection('Replies')
        .doc(parentReplyId)
        .collection('SubReplies')
        .doc(subReplyId);
    if (currentLikes.contains(uid)) {
      await ref.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([uid])
      });
    }
  }

  /// Add a nested reply to a parent reply
  Future<void> _addNestedReply(String parentReplyId) async {
    final text = _nestedReplyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _nestedReplyLoading = true);

    final moderation = await ContentModerationService.moderateReply(text);
    if (moderation.shouldReject) {
      if (mounted) setState(() => _nestedReplyLoading = false);
      AppSnackbar.error(moderation.userMessage, title: 'Reply Rejected');
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');
      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(currentUser.uid)
          .get();
      if (!userDoc.exists) throw Exception('User not found');
      final username = userDoc.data()?['Username'] ?? 'Anonymous';
      final profilePic = userDoc.data()?['profilePicture'] ?? '';

      final subRef = FirebaseFirestore.instance
          .collection('Discussions')
          .doc(widget.docId)
          .collection('Replies')
          .doc(parentReplyId)
          .collection('SubReplies')
          .doc();
      await subRef.set({
        'subReplyId': subRef.id,
        'reply': text,
        'user_name': username,
        'profilePicture': profilePic,
        'uid': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'qualityScore': moderation.qualityScore,
        'contentStatus': moderation.statusKey,
        'moderationFlags': moderation.flags,
      });

      _nestedReplyController.clear();
      _activeReplyId.value = null;
      _activeReplyUserName.value = null;
      AppSnackbar.success('Reply added!');
      await _gamificationService.awardXp(XpAction.postReply);
      await _gamificationService.incrementCounter('repliesCount');
      await _gamificationService.recordActivity();
    } catch (e) {
      AppSnackbar.error('Failed: $e');
    } finally {
      if (mounted) setState(() => _nestedReplyLoading = false);
    }
  }

  /// Relative time helper (e.g. "2h", "5d", "just now")
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  Future<void> updateXP(String uid) async {
    try {
      // Fetch the current XP value as a String
      final userDoc =
          await FirebaseFirestore.instance.collection('User').doc(uid).get();

      if (userDoc.exists) {
        // Get the current XP value (could be int or String)
        String currentXPString =
            userDoc.data()?['XP']?.toString() ?? '0'; // Convert to String
        int currentXP = int.tryParse(currentXPString) ??
            0; // Convert to int, default to 0 if parsing fails

        // Add 50 to the current XP
        int updatedXP = currentXP + 50;

        // Save the updated XP back to Firestore as a String
        await FirebaseFirestore.instance.collection('User').doc(uid).update({
          'XP': updatedXP.toString(),
          'lastXpUpdate': FieldValue.serverTimestamp(),
        });

        // Log XP history for sync
        await FirebaseFirestore.instance
            .collection('User')
            .doc(uid)
            .collection('xp_history')
            .add({
          'action': 'helpfulAnswer',
          'xp': 50,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Answer marked as helpful',
        });

        print('XP updated successfully to $updatedXP!');
      } else {
        print('User document not found.');
      }
    } catch (e) {
      print('Error updating XP: $e');
    }
  }

  Future<void> _reportDiscussion() async {
    try {
      await FirebaseFirestore.instance
          .collection('Discussions')
          .doc(widget.docId)
          .update({
        'Report': true,
        'reportedAt': FieldValue.serverTimestamp(),
        'reportedBy': user?.uid,
      });
      AppSnackbar.success(
          'Discussion reported. Our moderators will review it.');
    } catch (e) {
      AppSnackbar.error('Failed to report discussion: $e');
    }
  }

  Future<void> _notifyAcceptedReplyAuthor(
      Map<String, dynamic> replyData) async {
    // Push notifications disabled - no server-side function available.
    // To re-enable, deploy an Appwrite Function or backend that can call FCM.
    return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        title: Text(
          "Discussion Details",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          IconButton(
            tooltip: 'Report Discussion',
            icon: Icon(
              Icons.flag_outlined,
              color: isDark ? Colors.grey.shade200 : Colors.black87,
            ),
            onPressed: () async {
              final confirm = await AppDialogs.showConfirmation(
                context,
                title: 'Report Discussion',
                message:
                    'Do you want to report this discussion for moderator review?',
                confirmText: 'Report',
                cancelText: 'Cancel',
              );
              if (confirm == true) {
                await _reportDiscussion();
              }
            },
          ),
          IconButton(
            tooltip: 'Summarize Thread',
            icon: _summaryLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Icon(
                    Icons.summarize,
                    color: AppTheme.primaryColor,
                  ),
            onPressed: _summaryLoading
                ? null
                : () async {
                    setState(() {
                      _summaryLoading = true;
                      _threadSummary = null;
                    });
                    try {
                      // Fetch discussion doc & replies once.
                      final discSnap = await FirebaseFirestore.instance
                          .collection('Discussions')
                          .doc(widget.docId)
                          .get();
                      final repliesSnap = await FirebaseFirestore.instance
                          .collection('Discussions')
                          .doc(widget.docId)
                          .collection('Replies')
                          .orderBy('timestamp')
                          .get();
                      final title = discSnap.data()?['Title'] ?? 'Untitled';
                      final desc = discSnap.data()?['Description'] ?? '';
                      final replies =
                          repliesSnap.docs.map((d) => d.data()).toList();
                      final summary = await AIService().summarizeThread(
                          title: title,
                          description: desc,
                          replies: replies.cast<Map<String, dynamic>>());
                      if (mounted) {
                        setState(() {
                          _threadSummary = summary;
                        });
                        // Show in bottom sheet
                        if (summary.isNotEmpty) {
                          // ignore: use_build_context_synchronously
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor:
                                isDark ? AppTheme.darkCard : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            builder: (_) =>
                                _ThreadSummarySheet(summary: summary),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        AppSnackbar.error('Summary failed: $e');
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _summaryLoading = false;
                        });
                      }
                    }
                  },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.darkBg, AppTheme.darkBg.withValues(alpha: 0.95)]
                : [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _discussionStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildDetailDiscussionShimmer(theme, isDark);
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade600,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(
                      child: Text(
                        'Discussion not found.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade600,
                        ),
                      ),
                    );
                  }

                  var discussionData = snapshot.data!;
                  final discussionMap =
                      discussionData.data() as Map<String, dynamic>? ?? {};
                  final rawPoll = discussionMap['poll'];
                  final pollMap = rawPoll is Map
                      ? Map<String, dynamic>.from(rawPoll)
                      : null;
                  final hasPoll =
                      discussionMap['hasPoll'] == true && pollMap != null;

                  if (_isUnsafeContent(discussionMap)) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              size: 48,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'This content is not available.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'It was hidden by community safety moderation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isTopSectionCollapsed ? 'Discussion Overview' : 'Main Discussion',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _isTopSectionCollapsed = !_isTopSectionCollapsed),
                                    icon: Icon(
                                      _isTopSectionCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _isTopSectionCollapsed ? 'Show context' : 'Collapse',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 300),
                                crossFadeState: _isTopSectionCollapsed 
                                    ? CrossFadeState.showFirst 
                                    : CrossFadeState.showSecond,
                                firstChild: GestureDetector(
                                  onTap: () => setState(() => _isTopSectionCollapsed = false),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkCard.withValues(alpha: 0.5) : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          discussionData['Title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          discussionData['Description'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                secondChild: Column(
                                  children: [
                                    ScrollFadeIn(
                                      child: display_discussion(
                                        title: discussionData['Title'] ?? '',
                                        description:
                                            discussionData['Description'] ?? '',
                                        tags: List<String>.from(
                                            discussionData['Tags'] ?? []),
                                        timestamp:
                                            (discussionData['Timestamp'] as Timestamp?)
                                                    ?.toDate() ??
                                                DateTime.now(),
                                        uid: discussionData['Uid'] ?? '',
                                        docid: widget.docId,
                                        replies: [],
                                      ),
                                    ),
                                    if (hasPoll) ...[
                                      const SizedBox(height: 8),
                                      PollDisplayWidget(
                                        poll: Poll.fromMap(pollMap),
                                        parentId: widget.docId,
                                        parentCollection: 'Discussions',
                                        onVoted: () {
                                          if (mounted) setState(() {});
                                        },
                                        canDelete: false,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 12),
                            // ── Reddit-style replies divider ──
                            // ── Simple Discussion Header ──
                            Row(
                              children: [
                                Text(
                                  'COMMENTS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Divider(
                                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                    thickness: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.sort_rounded,
                                  size: 14,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Oldest',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ]),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: _repliesStream,
                        builder: (context, repliesSnapshot) {
                          if (repliesSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SliverToBoxAdapter(
                              child: _buildRepliesShimmer(theme, isDark),
                            );
                          }
                          if (repliesSnapshot.hasError) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Text(
                                  'Error: ${repliesSnapshot.error}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (repliesSnapshot.data?.docs.isEmpty ?? true) {
                            return SliverToBoxAdapter(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 40, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkCard.withValues(alpha: 0.5)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 40,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Be the first to reply',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Share your thoughts on this discussion',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final replies =
                              repliesSnapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return !_isUnsafeContent(data);
                          }).toList();

                          if (replies.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 40, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkCard.withValues(alpha: 0.5)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 40,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Be the first to reply',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Share your thoughts on this discussion',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  var replyData = replies[index].data()
                                      as Map<String, dynamic>;
                                  final bool isAccepted =
                                      replyData['accepted'] == true;
                                  final bool isOwner =
                                      user?.uid == replyData['uid'];
                                  final DateTime replyTime =
                                      replyData['timestamp'] != null
                                          ? (replyData['timestamp']
                                                  as Timestamp)
                                              .toDate()
                                          : DateTime.now();
                                  final List<dynamic> likes =
                                      replyData['likes'] ?? [];
                                  final bool isLiked =
                                      user != null && likes.contains(user!.uid);
                                  final String replyId =
                                      replyData['replyId'] ?? '';

                                  // Thread line color cycling
                                  final threadColors = [
                                    AppTheme.primaryColor,
                                    const Color(0xFFFF6B6B),
                                    const Color(0xFF51CF66),
                                    const Color(0xFFFCC419),
                                    const Color(0xFFCC5DE8),
                                    const Color(0xFF22B8CF),
                                  ];
                                  final threadColor =
                                      threadColors[index % threadColors.length];

                                  return GestureDetector(
                                    onLongPress: () async {
                                      if (isOwner) {
                                        bool? confirmDelete =
                                            await AppDialogs.showConfirmation(
                                          context,
                                          title: 'Delete Reply',
                                          message:
                                              'Are you sure you want to delete this reply?',
                                          confirmText: 'Delete',
                                          cancelText: 'Cancel',
                                          barrierDismissible: false,
                                        );
                                        if (confirmDelete == true) {
                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('Discussions')
                                                .doc(widget.docId)
                                                .collection('Replies')
                                                .doc(replyId)
                                                .delete();
                                            AppSnackbar.success(
                                                'Reply deleted successfully!');
                                          } catch (e) {
                                            AppSnackbar.error(
                                                'Failed to delete reply: $e');
                                          }
                                        }
                                        if (replyData['accepted'] == true) {
                                          updateXP2(replyData['uid'], 50);
                                        }
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 2),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // ── Thread line ──
                                            GestureDetector(
                                              onTap: () {},
                                              child: Container(
                                                width: 20,
                                                alignment: Alignment.center,
                                                child: Container(
                                                  width: 3,
                                                  decoration: BoxDecoration(
                                                    color: isAccepted
                                                        ? AppTheme.successColor
                                                        : threadColor
                                                            .withValues(
                                                                alpha: isDark
                                                                    ? 0.5
                                                                    : 0.35),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // ── Reply content area ──
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 4),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: isDark
                                                          ? Colors.grey.shade800
                                                          : Colors
                                                              .grey.shade200,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // ── Accepted badge ──
                                                    if (isAccepted)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(bottom: 8),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppTheme
                                                              .successColor
                                                              .withValues(
                                                                  alpha: isDark
                                                                      ? 0.15
                                                                      : 0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                              color: AppTheme
                                                                  .successColor
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .check_circle,
                                                                color: AppTheme
                                                                    .successColor,
                                                                size: 14),
                                                            const SizedBox(
                                                                width: 4),
                                                            Text(
                                                                'Accepted Answer',
                                                                style: TextStyle(
                                                                    color: AppTheme
                                                                        .successColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        11)),
                                                          ],
                                                        ),
                                                      ),

                                                    // ── User header ──
                                                    Row(
                                                      children: [
                                                        ScrollFadeIn(
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      320),
                                                          slideOffset: 10,
                                                          delay: Duration(
                                                              milliseconds:
                                                                  (index % 6) *
                                                                      35),
                                                          child: FutureBuilder<
                                                              String?>(
                                                            future:
                                                                _fetchUserProfileImage(
                                                                    replyData[
                                                                        'uid']),
                                                            builder: (context,
                                                                snapshot) {
                                                              if (snapshot
                                                                      .connectionState ==
                                                                  ConnectionState
                                                                      .waiting) {
                                                                return CircleAvatar(
                                                                    radius: 14,
                                                                    backgroundColor: isDark
                                                                        ? Colors
                                                                            .grey
                                                                            .shade700
                                                                        : Colors
                                                                            .grey
                                                                            .shade300);
                                                              } else if (snapshot
                                                                      .hasError ||
                                                                  snapshot.data ==
                                                                      null ||
                                                                  snapshot.data!
                                                                      .isEmpty) {
                                                                return CircleAvatar(
                                                                  radius: 14,
                                                                  backgroundColor: isDark
                                                                      ? AppTheme
                                                                          .darkSurface
                                                                      : Colors
                                                                          .grey
                                                                          .shade200,
                                                                  child: Text(
                                                                    replyData['user_name']?.isNotEmpty ==
                                                                            true
                                                                        ? replyData['user_name'][0]
                                                                            .toUpperCase()
                                                                        : '?',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: isDark
                                                                            ? Colors.white
                                                                            : Colors.black87),
                                                                  ),
                                                                );
                                                              } else {
                                                                return CircleAvatar(
                                                                    radius: 14,
                                                                    backgroundImage:
                                                                        NetworkImage(
                                                                            snapshot.data!));
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                            replyData[
                                                                    'user_name'] ??
                                                                'Unknown',
                                                            style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: isDark
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black87)),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text('•',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: isDark
                                                                    ? Colors
                                                                        .grey
                                                                        .shade500
                                                                    : Colors
                                                                        .grey
                                                                        .shade400)),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                            _relativeTime(
                                                                replyTime),
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey
                                                                    .shade500)),
                                                        const Spacer(),
                                                        FutureBuilder<String?>(
                                                          future: _fetchUserXP(
                                                              replyData['uid']),
                                                          builder: (context,
                                                              snapshot) {
                                                            if (snapshot
                                                                    .hasData &&
                                                                snapshot.data !=
                                                                    null) {
                                                              return Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: AppTheme
                                                                      .primaryColor
                                                                      .withValues(
                                                                          alpha: isDark
                                                                              ? 0.2
                                                                              : 0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                ),
                                                                child: Text(
                                                                    '${snapshot.data} XP',
                                                                    style: TextStyle(
                                                                        color: AppTheme
                                                                            .primaryColor,
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight.w600)),
                                                              );
                                                            }
                                                            return const SizedBox
                                                                .shrink();
                                                          },
                                                        ),
                                                        if (isOwner)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 4),
                                                            child: Icon(
                                                                Icons
                                                                    .more_horiz,
                                                                size: 16,
                                                                color: isDark
                                                                    ? Colors
                                                                        .grey
                                                                        .shade500
                                                                    : Colors
                                                                        .grey
                                                                        .shade400),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),

                                                    // ── Reply text ──
                                                    RichText(
                                                      text: TextSpan(
                                                        style: TextStyle(
                                                            color: isDark
                                                                ? Colors.grey
                                                                    .shade200
                                                                : Colors
                                                                    .black87,
                                                            fontSize: 14,
                                                            height: 1.5),
                                                        children:
                                                            _buildDescription(
                                                                replyData[
                                                                        'reply'] ??
                                                                    '',
                                                                Theme.of(
                                                                    context)),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),

                                                    // ══════════════════════════════════════
                                                    // ── ACTION BAR: Like, Reply, Code, Accept ──
                                                    // ══════════════════════════════════════
                                                    Row(
                                                      children: [
                                                        // ── Like button ──
                                                        _buildActionChip(
                                                          icon: isLiked
                                                              ? Icons.favorite
                                                              : Icons
                                                                  .favorite_border,
                                                          label: likes.isEmpty
                                                              ? 'Like'
                                                              : '${likes.length}',
                                                          color: isLiked
                                                              ? const Color(
                                                                  0xFFFF6B6B)
                                                              : (isDark
                                                                  ? Colors.grey
                                                                      .shade400
                                                                  : Colors.grey
                                                                      .shade600),
                                                          isDark: isDark,
                                                          onTap: () =>
                                                              _toggleLike(
                                                                  replyId,
                                                                  likes),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),

                                                        // ── Reply button ──
                                                        _buildActionChip(
                                                          icon: Icons
                                                              .reply_rounded,
                                                          label: 'Reply',
                                                          color: isDark
                                                              ? Colors
                                                                  .grey.shade400
                                                              : Colors.grey
                                                                  .shade600,
                                                          isDark: isDark,
                                                          onTap: () {
                                                            if (_activeReplyId
                                                                    .value ==
                                                                replyId) {
                                                              _activeReplyId
                                                                  .value = null;
                                                              _activeReplyUserName
                                                                  .value = null;
                                                            } else {
                                                              _activeReplyId
                                                                      .value =
                                                                  replyId;
                                                              _activeReplyUserName
                                                                      .value =
                                                                  replyData[
                                                                          'user_name'] ??
                                                                      'Unknown';
                                                              _nestedReplyController
                                                                  .clear();
                                                            }
                                                          },
                                                        ),
                                                        const SizedBox(
                                                            width: 8),

                                                        // ── Code button ──
                                                        if (replyData['code']
                                                            .toString()
                                                            .isNotEmpty)
                                                          _buildActionChip(
                                                            icon: Icons
                                                                .code_rounded,
                                                            label: 'Code',
                                                            color: AppTheme
                                                                .primaryColor,
                                                            isDark: isDark,
                                                            onTap: () {
                                                              final codeText =
                                                                  replyData['code']
                                                                          as String? ??
                                                                      '';
                                                              var isCodePreviewLoading =
                                                                  true;
                                                              var shimmerScheduled =
                                                                  false;
                                                              showModalBottomSheet(
                                                                context:
                                                                    context,
                                                                isScrollControlled:
                                                                    true,
                                                                backgroundColor: isDark
                                                                    ? AppTheme
                                                                        .darkCard
                                                                    : theme
                                                                        .colorScheme
                                                                        .surface,
                                                                shape:
                                                                    const RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.vertical(
                                                                          top: Radius.circular(
                                                                              20)),
                                                                ),
                                                                builder: (ctx) {
                                                                  final bottomTheme =
                                                                      Theme.of(
                                                                          ctx);
                                                                  final cs =
                                                                      bottomTheme
                                                                          .colorScheme;

                                                                  return StatefulBuilder(
                                                                    builder:
                                                                        (context,
                                                                            setModalState) {
                                                                      if (isCodePreviewLoading &&
                                                                          !shimmerScheduled) {
                                                                        shimmerScheduled =
                                                                            true;
                                                                        Future
                                                                            .delayed(
                                                                          const Duration(
                                                                              milliseconds: 550),
                                                                          () {
                                                                            if (context.mounted) {
                                                                              setModalState(() => isCodePreviewLoading = false);
                                                                            }
                                                                          },
                                                                        );
                                                                      }

                                                                      return SafeArea(
                                                                        top:
                                                                            false,
                                                                        child:
                                                                            Padding(
                                                                          padding:
                                                                              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                                                                          child:
                                                                              Container(
                                                                            constraints:
                                                                                BoxConstraints(
                                                                              maxHeight: MediaQuery.of(ctx).size.height * 0.78,
                                                                            ),
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              color: bottomTheme.dialogTheme.backgroundColor ?? (isDark ? AppTheme.darkCard : bottomTheme.colorScheme.surface),
                                                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                                              border: Border.all(
                                                                                color: cs.outlineVariant.withValues(alpha: 0.35),
                                                                                width: 1,
                                                                              ),
                                                                            ),
                                                                            child:
                                                                                Column(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                const SizedBox(height: 8),
                                                                                Container(
                                                                                  width: 44,
                                                                                  height: 4,
                                                                                  decoration: BoxDecoration(
                                                                                    color: cs.outlineVariant,
                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                  ),
                                                                                ),
                                                                                Padding(
                                                                                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
                                                                                  child: Row(
                                                                                    children: [
                                                                                      Container(
                                                                                        padding: const EdgeInsets.all(8),
                                                                                        decoration: BoxDecoration(
                                                                                          color: cs.primary.withValues(alpha: 0.12),
                                                                                          borderRadius: BorderRadius.circular(10),
                                                                                        ),
                                                                                        child: Icon(
                                                                                          Icons.code_rounded,
                                                                                          color: cs.primary,
                                                                                          size: 18,
                                                                                        ),
                                                                                      ),
                                                                                      const SizedBox(width: 10),
                                                                                      Expanded(
                                                                                        child: Column(
                                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                                          children: [
                                                                                            Text(
                                                                                              'Code Snippet',
                                                                                              style: bottomTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                                                                            ),
                                                                                            Text(
                                                                                              '${codeText.split('\n').length} lines',
                                                                                              style: bottomTheme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                      IconButton(
                                                                                        tooltip: 'Copy code',
                                                                                        onPressed: () {
                                                                                          Clipboard.setData(ClipboardData(text: codeText));
                                                                                          AppSnackbar.success('Code copied');
                                                                                        },
                                                                                        icon: Icon(
                                                                                          Icons.copy_rounded,
                                                                                          size: 18,
                                                                                          color: cs.onSurfaceVariant,
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                                Flexible(
                                                                                  child: AnimatedSwitcher(
                                                                                    duration: const Duration(milliseconds: 220),
                                                                                    child: isCodePreviewLoading
                                                                                        ? _buildCodeSnippetShimmer(bottomTheme, isDark)
                                                                                        : SingleChildScrollView(
                                                                                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                                                                                            child: Container(
                                                                                              width: double.infinity,
                                                                                              padding: const EdgeInsets.all(14),
                                                                                              decoration: BoxDecoration(
                                                                                                color: isDark ? AppTheme.darkSurface : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                                                                                                borderRadius: BorderRadius.circular(14),
                                                                                                border: Border.all(
                                                                                                  color: cs.outlineVariant.withValues(alpha: 0.45),
                                                                                                ),
                                                                                              ),
                                                                                              child: MarkdownBody(
                                                                                                data: "```\n$codeText\n```",
                                                                                                selectable: true,
                                                                                                styleSheet: AppMarkdownStyles.getCodeStyle(context),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          )
                                                        else if (isOwner)
                                                          _buildActionChip(
                                                            icon: Icons
                                                                .attach_file_rounded,
                                                            label: 'Code',
                                                            color: isDark
                                                                ? Colors.grey
                                                                    .shade400
                                                                : Colors.grey
                                                                    .shade600,
                                                            isDark: isDark,
                                                            onTap: () => Get.to(
                                                                () => attachcode(
                                                                    docId:
                                                                        replyId,
                                                                    discussionId:
                                                                        widget
                                                                            .docId)),
                                                          ),

                                                        const Spacer(),

                                                        // ── Accept button ──
                                                        if (!isAccepted)
                                                          FutureBuilder<User?>(
                                                            future: FirebaseAuth
                                                                .instance
                                                                .authStateChanges()
                                                                .first,
                                                            builder: (context,
                                                                snapshot) {
                                                              if (snapshot
                                                                      .hasData &&
                                                                  snapshot.data!
                                                                          .uid ==
                                                                      widget
                                                                          .creatorId &&
                                                                  user?.uid !=
                                                                      replyData[
                                                                          'uid']) {
                                                                return _buildActionChip(
                                                                  icon: Icons
                                                                      .check_circle_outline_rounded,
                                                                  label:
                                                                      'Accept',
                                                                  color: AppTheme
                                                                      .successColor,
                                                                  isDark:
                                                                      isDark,
                                                                  onTap:
                                                                      () async {
                                                                    try {
                                                                      await FirebaseFirestore
                                                                          .instance
                                                                          .collection(
                                                                              'Discussions')
                                                                          .doc(widget
                                                                              .docId)
                                                                          .collection(
                                                                              'Replies')
                                                                          .doc(
                                                                              replyId)
                                                                          .update({
                                                                        'accepted':
                                                                            true
                                                                      });
                                                                      updateXP(
                                                                          replyData[
                                                                              'uid']);
                                                                      await _notifyAcceptedReplyAuthor(
                                                                          replyData);
                                                                      AppSnackbar
                                                                          .success(
                                                                              'Reply accepted!');
                                                                    } catch (e) {
                                                                      AppSnackbar
                                                                          .error(
                                                                              'Failed to accept: $e');
                                                                    }
                                                                  },
                                                                );
                                                              }
                                                              return const SizedBox
                                                                  .shrink();
                                                            },
                                                          ),
                                                      ],
                                                    ),

                                                    // ══════════════════════════════════════
                                                    // ── INLINE NESTED REPLY INPUT ──
                                                    // ══════════════════════════════════════
                                                    ValueListenableBuilder<
                                                        String?>(
                                                      valueListenable:
                                                          _activeReplyId,
                                                      builder: (context,
                                                          activeReplyId, _) {
                                                        if (activeReplyId !=
                                                            replyId) {
                                                          return const SizedBox
                                                              .shrink();
                                                        }
                                                        return Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 10),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(10),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? AppTheme
                                                                    .darkSurface
                                                                : Colors.grey
                                                                    .shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color: isDark
                                                                  ? Colors.grey
                                                                      .shade700
                                                                  : Colors.grey
                                                                      .shade300,
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .reply,
                                                                      size: 14,
                                                                      color: AppTheme
                                                                          .primaryColor),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Text(
                                                                      'Replying to ',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color: isDark
                                                                              ? Colors.grey.shade400
                                                                              : Colors.grey.shade600)),
                                                                  Text(
                                                                      _activeReplyUserName
                                                                              .value ??
                                                                          '',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight: FontWeight
                                                                              .w600,
                                                                          color:
                                                                              AppTheme.primaryColor)),
                                                                  const Spacer(),
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      _activeReplyId
                                                                              .value =
                                                                          null;
                                                                      _activeReplyUserName
                                                                              .value =
                                                                          null;
                                                                    },
                                                                    child: Icon(
                                                                        Icons
                                                                            .close,
                                                                        size:
                                                                            16,
                                                                        color: isDark
                                                                            ? Colors.grey.shade500
                                                                            : Colors.grey.shade400),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                  height: 8),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        TextField(
                                                                      controller:
                                                                          _nestedReplyController,
                                                                      maxLines:
                                                                          2,
                                                                      minLines:
                                                                          1,
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          color: isDark
                                                                              ? Colors.white
                                                                              : Colors.black87),
                                                                      decoration:
                                                                          InputDecoration(
                                                                        hintText:
                                                                            'Write a reply...',
                                                                        hintStyle: TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            color: isDark
                                                                                ? Colors.grey.shade500
                                                                                : Colors.grey.shade400),
                                                                        border:
                                                                            InputBorder.none,
                                                                        contentPadding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                12,
                                                                            vertical:
                                                                                8),
                                                                        isDense:
                                                                            true,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 8),
                                                                  GestureDetector(
                                                                    onTap: _nestedReplyLoading
                                                                        ? null
                                                                        : () =>
                                                                            _addNestedReply(replyId),
                                                                    child:
                                                                        Container(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .all(
                                                                              8),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        gradient:
                                                                            AppTheme.primaryGradient,
                                                                        shape: BoxShape
                                                                            .circle,
                                                                      ),
                                                                      child: _nestedReplyLoading
                                                                          ? const SizedBox(
                                                                              width: 16,
                                                                              height: 16,
                                                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                                          : const Icon(Icons.send, color: Colors.white, size: 16),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),

                                                    // ══════════════════════════════════════
                                                    // ── NESTED SUB-REPLIES (Gemini-style) ──
                                                    // ══════════════════════════════════════
                                                    StreamBuilder<
                                                        QuerySnapshot>(
                                                      stream: FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                              'Discussions')
                                                          .doc(widget.docId)
                                                          .collection('Replies')
                                                          .doc(replyId)
                                                          .collection(
                                                              'SubReplies')
                                                          .orderBy('timestamp')
                                                          .snapshots(),
                                                      builder: (context,
                                                          subSnapshot) {
                                                        if (!subSnapshot
                                                                .hasData ||
                                                            subSnapshot.data!
                                                                .docs.isEmpty) {
                                                          return const SizedBox
                                                              .shrink();
                                                        }
                                                        final subReplies =
                                                            subSnapshot
                                                                .data!.docs;
                                                        return Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 10,
                                                                  left: 16),
                                                          child: Column(
                                                            children: subReplies
                                                                .map((subDoc) {
                                                              final sub = subDoc
                                                                      .data()
                                                                  as Map<String,
                                                                      dynamic>;
                                                              final subLikes =
                                                                  (sub['likes']
                                                                          as List<
                                                                              dynamic>?) ??
                                                                      [];
                                                              final subIsLiked = user !=
                                                                      null &&
                                                                  subLikes.contains(
                                                                      user!
                                                                          .uid);
                                                              final subTime = sub[
                                                                          'timestamp'] !=
                                                                      null
                                                                  ? (sub['timestamp']
                                                                          as Timestamp)
                                                                      .toDate()
                                                                  : DateTime
                                                                      .now();
                                                              return Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            8),
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        12),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: isDark
                                                                      ? AppTheme
                                                                          .primaryColor
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.12)
                                                                      : Colors
                                                                          .blue
                                                                          .withValues(
                                                                              alpha: 0.05),
                                                                  borderRadius:
                                                                      const BorderRadius
                                                                          .only(
                                                                    topRight: Radius
                                                                        .circular(
                                                                            16),
                                                                    bottomRight:
                                                                        Radius.circular(
                                                                            16),
                                                                    bottomLeft:
                                                                        Radius.circular(
                                                                            16),
                                                                    topLeft: Radius
                                                                        .circular(
                                                                            4),
                                                                  ),
                                                                  border: Border
                                                                      .all(
                                                                    color: AppTheme
                                                                        .primaryColor
                                                                        .withValues(
                                                                            alpha: isDark
                                                                                ? 0.3
                                                                                : 0.15),
                                                                    width: 0.5,
                                                                  ),
                                                                ),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    // Sub-reply header
                                                                    Row(
                                                                      children: [
                                                                        FutureBuilder<
                                                                            String?>(
                                                                          future:
                                                                              _fetchUserProfileImage(sub['uid'] ?? ''),
                                                                          builder:
                                                                              (context, snap) {
                                                                            return CircleAvatar(
                                                                              radius: 9,
                                                                              backgroundImage: snap.hasData && snap.data != null && snap.data!.isNotEmpty ? NetworkImage(snap.data!) : null,
                                                                              child: (!snap.hasData || snap.data == null || snap.data!.isEmpty) ? Text(sub['user_name']?[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 8)) : null,
                                                                            );
                                                                          },
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                8),
                                                                        Text(
                                                                            sub['user_name'] ??
                                                                                'Unknown',
                                                                            style: TextStyle(
                                                                                fontSize: 12,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: isDark ? Colors.white : Colors.black87)),
                                                                        const SizedBox(
                                                                            width:
                                                                                6),
                                                                        Text(
                                                                            _relativeTime(
                                                                                subTime),
                                                                            style:
                                                                                TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            6),
                                                                    Text(
                                                                        sub['reply'] ??
                                                                            '',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            height:
                                                                                1.4,
                                                                            color: isDark
                                                                                ? Colors.grey.shade300
                                                                                : Colors.black87)),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    GestureDetector(
                                                                      onTap: () => _toggleNestedLike(
                                                                          replyId,
                                                                          sub['subReplyId'] ??
                                                                              '',
                                                                          subLikes),
                                                                      child:
                                                                          Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                            subIsLiked
                                                                                ? Icons.favorite
                                                                                : Icons.favorite_border,
                                                                            size:
                                                                                13,
                                                                            color: subIsLiked
                                                                                ? const Color(0xFFFF6B6B)
                                                                                : Colors.grey.shade500,
                                                                          ),
                                                                          if (subLikes
                                                                              .isNotEmpty) ...[
                                                                            const SizedBox(width: 3),
                                                                            Text('${subLikes.length}',
                                                                                style: TextStyle(fontSize: 11, color: subIsLiked ? const Color(0xFFFF6B6B) : Colors.grey.shade500)),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            }).toList(),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: replies.length,
                              ),
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  );
                },
              ),
            ),
            // Modern reply input section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Modern text field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _replyController,
                          maxLines: 1,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add your opinion...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          overlayColor:
                              MaterialStateProperty.all(Colors.transparent),
                          onTap: _isLoading
                              ? null
                              : () {
                                  if (_replyController.text.trim().isNotEmpty) {
                                    addReply();
                                  }
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailDiscussionShimmer(ThemeData theme, bool isDark) {
    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final highlightColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : theme.colorScheme.surface.withValues(alpha: 0.95);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 18,
            width: 120,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 92,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesShimmer(ThemeData theme, bool isDark) {
    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final highlightColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : theme.colorScheme.surface.withValues(alpha: 0.95);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          children: List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 84,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a compact action chip for reply action bars (Reddit-style)
  Widget _buildCodeSnippetShimmer(ThemeData theme, bool isDark) {
    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final highlightColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : theme.colorScheme.surface.withValues(alpha: 0.95);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              9,
              (index) => Container(
                height: 10,
                width: index.isEven ? double.infinity : 220,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a compact action chip for reply action bars (Reddit-style)
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class display_discussion extends StatefulWidget {
  final String title;
  final String description;
  final List<String> tags;
  final String uid;
  final String docid;
  final DateTime timestamp;
  final List<String> replies; // Added to store replies as a list of reply IDs

  const display_discussion({
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
  display_discussionCardState createState() => display_discussionCardState();
}

class display_discussionCardState extends State<display_discussion> {
  Future<String?> _fetchUserName(String uid) async {
    try {
      final userData = await UserCacheService.instance.getUserData(uid);
      return userData['Username'] as String? ?? 'Unknown User';
    } catch (e) {
      print('Error fetching user data: $e');
      return 'Error';
    }
  }

  bool isLiked = false;
  bool isFetchingUserName = false;
  late Future<String?> _userNameFuture;
  late Future<String?> _userProfileImageFuture;
  late Future<String?> _userXpFuture;
  bool _showFullTitle = false;
  bool _showFullDescription = false;

  void _openFullContentSheet(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      children: _buildDescription(widget.description, theme),
                    ),
                  ),
                  if (widget.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _userNameFuture = _fetchUserName(widget.uid);
    _userProfileImageFuture = _fetchUserProfileImage(widget.uid);
    _userXpFuture = _fetchUserXP(widget.uid);
    // _checkIfLiked();
    // Access the parameters with widget.parameterName
  }

  Future<String?> _fetchUserProfileImage(String uid) async {
    try {
      final userData = await UserCacheService.instance.getUserData(uid);
      return userData['profilePicture'] as String?;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<String?> _fetchUserXP(String uid) async {
    try {
      final userData = await UserCacheService.instance.getUserData(uid);
      return userData['XP']?.toString() ?? '100';
    } catch (e) {
      print('Error fetching user data: $e');
      return '100';
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

    AppSnackbar.success('Discussion Saved', title: 'Success');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _openFullContentSheet(theme),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── User Info Row ──
                Row(
                  children: [
                    // Avatar
                    FutureBuilder<String?>(
                      future: _userProfileImageFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 18,
                            backgroundColor: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade200,
                          );
                        }
                        final url = snapshot.data;
                        if (url == null || url.isEmpty) {
                          return FutureBuilder<String?>(
                            future: _userNameFuture,
                            builder: (ctx, nameSnap) {
                              final initial = ((nameSnap.data ?? '?').isNotEmpty)
                                  ? (nameSnap.data ?? '?')[0].toUpperCase()
                                  : '?';
                              return CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        return CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(url),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // Username
                    Expanded(
                      child: FutureBuilder<String?>(
                        future: _userNameFuture,
                        builder: (context, snapshot) {
                          final name = snapshot.data ?? '…';
                          return Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    // XP Badge
                    FutureBuilder<String?>(
                      future: _userXpFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(width: 50, height: 24);
                        }
                        final xp = snapshot.data ?? '0';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$xp XP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Title ──
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: _showFullTitle ? null : 2,
                  overflow:
                      _showFullTitle ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (widget.title.trim().length > 80)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showFullTitle = !_showFullTitle),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _showFullTitle ? 'Show less' : 'Read more',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 6),

                // ── Description ──
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade300
                          : const Color(0xFF475569),
                    ),
                    children: _buildDescription(widget.description, theme),
                  ),
                  maxLines: _showFullDescription ? null : 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.description.trim().length > 220)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() =>
                              _showFullDescription = !_showFullDescription),
                          child: Text(
                            _showFullDescription ? 'Show less' : 'Read more',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _openFullContentSheet(theme),
                          child: Text(
                            'View full',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
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

class _ThreadSummarySheet extends StatefulWidget {
  final String summary;
  const _ThreadSummarySheet({required this.summary});

  @override
  State<_ThreadSummarySheet> createState() => _ThreadSummarySheetState();
}

class _ThreadSummarySheetState extends State<_ThreadSummarySheet> {
  bool _expanded = true;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.summarize),
                SizedBox(width: 8),
                Expanded(
                  child: Text('AI Thread Summary',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
                IconButton(
                  tooltip: 'Copy Markdown',
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: widget.summary));
                    setState(() => _copied = true);
                    Future.delayed(Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                    if (context.mounted) {
                      AppSnackbar.success('Summary copied to clipboard');
                    }
                  },
                  icon: Icon(_copied ? Icons.check : Icons.copy),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: AnimatedCrossFade(
              duration: Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Markdown(
                controller: scrollController,
                data: widget.summary,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h2: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                  listBullet: theme.textTheme.bodyMedium,
                  p: theme.textTheme.bodyMedium,
                  blockquoteDecoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              secondChild: Center(
                child: Text('Collapsed', style: theme.textTheme.bodySmall),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _expanded = true),
                  icon: Icon(Icons.visibility),
                  label: Text('Expand'),
                ),
                SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: widget.summary));
                    if (context.mounted) {
                      AppSnackbar.success('Copied');
                    }
                  },
                  icon: Icon(Icons.copy_all),
                  label: Text('Copy'),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
