import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'detail_discussion.dart';
import 'services/user_cache_service.dart';
import 'widgets/modern_widgets.dart';
import 'utils/app_snackbar.dart';

// if (snapshot.connectionState == ConnectionState.waiting) {
// return Center(child: CircularProgressIndicator());
// }
// if (snapshot.hasError) {
// return Center(child: Text('Error: ${snapshot.error}'));
// }
// if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
// return Center(child: Text('No Post found.'));
// }
//
// var docs = snapshot.data!.docs
//     .where((doc) => documentIds.contains(doc.id))
//     .toList();
// if (docs.length == 0){
// return Center(child: Text('No saved IDs available'));
// }else {

// );

class saved_discussion extends StatefulWidget {
  const saved_discussion({super.key});

  @override
  State<saved_discussion> createState() => _saved_discussionState();
}

class _saved_discussionState extends State<saved_discussion> {
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String imageUrl = '';
  TextEditingController search_controller = TextEditingController();

  var discussionStream = FirebaseFirestore.instance
      .collection('Discussions')
      .where('Report', isEqualTo: false)
      .snapshots();

  final savedIdsStream = FirebaseFirestore.instance
      .collection('User')
      .doc(FirebaseAuth
          .instance.currentUser?.uid) // Replace with the actual document ID
      .snapshots();
  all() {
    setState(() {
      discussionStream = FirebaseFirestore.instance
          .collection('Discussions')
          .where('Report', isEqualTo: false)
          .snapshots();
    });
    // search_controller.clear();
  }

  fetchuser() async {
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('User')
          .doc(user?.uid)
          .get();
      print(userData);
      if (userData.exists) {
        setState(() {
          username = userData['Username'] ?? 'No name available';
          imageUrl = userData['profilePicture'];
        });
      } else {
        setState(() {
          username = 'No name available';
        });
      }
    }
  }

  onSearch2(String msg) {
    if (msg.isNotEmpty) {
      setState(() {
        discussionStream = FirebaseFirestore.instance
            .collection('Discussions')
            .where('Report', isEqualTo: false)
            .where("Title", isGreaterThanOrEqualTo: msg.capitalizeFirst)
            .where("Title", isLessThan: '${msg.capitalizeFirst}z')
            .snapshots();
      });
    } else {
      setState(() {
        discussionStream = FirebaseFirestore.instance
            .collection('Discussions')
            .where('Report', isEqualTo: false)
            .snapshots();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchuser();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
        backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
        appBar: AppBar(
          title: Text('Saved Discussions'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary
                      .withValues(alpha: isDark ? 0.3 : 0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        body: StreamBuilder(
          stream: savedIdsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load saved discussions',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: ListShimmer(itemCount: 4),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildEmptyState(theme, isDark);
            }
            // final questions = snapshot.data!.docs;
            List<String> documentIds =
                List.from(snapshot.data!['SavedDiscussion'] ?? []);
            return FutureBuilder<List<DocumentSnapshot>>(
              future: () async {
                List<DocumentSnapshot> allDocs = [];
                for(var i = 0; i < documentIds.length; i += 10) {
                  var chunk = documentIds.sublist(i, (i + 10 > documentIds.length) ? documentIds.length : i + 10);
                  final query = await FirebaseFirestore.instance.collection('Discussions')
                      .where(FieldPath.documentId, whereIn: chunk).get();
                  allDocs.addAll(query.docs);
                }
                return allDocs;
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListShimmer(itemCount: 4),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(theme, isDark);
                }

                var docs = snapshot.data!;
                if (docs.isEmpty) {
                  return _buildEmptyState(theme, isDark);
                } else {
                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>?;
                      if (data == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: displayCard(
                          title: data['Title'] ?? '',
                          description: data['Description'] ?? '',
                          tags: List<String>.from(data['Tags'] ?? []),
                          timestamp:
                              (data['Timestamp'] as Timestamp?)?.toDate() ??
                                  DateTime.now(),
                          uid: data['Uid'] ?? '',
                          docid: docs[index].id,
                          replies: [],
                        ),
                      );
                    },
                  );
                }
              },
            );
          },
        ));
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 30,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No saved discussions yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Save discussions from the feed and they will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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

  const displayCard({
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
  bool isLiked = false;
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = UserCacheService.instance.getUserData(widget.uid);
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



  removesaved(itemId) async {
    try {
      var usercredential = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection("User")
          .doc(usercredential?.uid)
          .update({
        'SavedDiscussion': FieldValue.arrayRemove([itemId])
      });
      AppSnackbar.success('Unsaved the Discussion');
    } catch (e) {
      AppSnackbar.error('Failed to unsave discussion');
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
    return Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              // Logic to handle card click, for example, navigating to a discussion detail screen
              Get.to(detail_discussion(
                docId: widget.docid,
                creatorId: widget.uid,
              ));
            },
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerLow
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Row (Profile Picture and Username)
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
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            foregroundImage: hasImage
                                ? NetworkImage(imageUrl)
                                : const NetworkImage(
                                    'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                                  ),
                          ),
                          const SizedBox(width: 8), // Space between avatar and text
                          // Fetch and display the user's name
                          Text(
                            "~ $userName",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (userXP != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$userXP XP',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  // Space between user info and title
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: isDark ? Colors.grey.shade300 : Colors.black87,
                      ),
                      children: _buildDescription(widget.description, theme),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // code = widget.code!!
                  if (widget.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.comment_bank_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_repliesCount',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              removesaved(widget.docid);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.bookmark_remove_rounded,
                                size: 17,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Posted ${_formatDate(widget.timestamp)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )));
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
