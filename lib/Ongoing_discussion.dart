import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/add_discussion.dart';
import 'package:developer_community_app/detail_discussion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class ongoing_discussion extends StatefulWidget {
   ongoing_discussion({super.key});

  @override
  State<ongoing_discussion> createState() => _ongoing_discussionState();
}

class _ongoing_discussionState extends State<ongoing_discussion> {
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String imageUrl = '';
  TextEditingController search_controller = TextEditingController();

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
          imageUrl = userData['profilePicture'] ?? null;
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
      // if(selectedSubject!.isNotEmpty){
      setState(() {
        discussionStream = FirebaseFirestore.instance
            .collection('Discussions')
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
    // print(exploreStream.toString());
  }

  @override
  void initState() {
    super.initState();
    fetchuser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('DevSphere'),
          automaticallyImplyLeading: false,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Get.to(add_discussion());
          },
          tooltip: 'Ask Question',
          child: Icon(Icons.add),
        ),
        body: Column(children: [
          Padding(
            padding:  EdgeInsets.all(8.0),
            child: CupertinoSearchTextField(
              onSuffixTap: () => {all()},
              controller: search_controller,
              placeholder: "Search",
              onChanged: (val) => {onSearch2(val), print(val)},
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: discussionStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No Post found.'));
                }

                final questions = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final data = questions[index].data();
                    return displayCard(
                      title: data['Title'] ?? '',
                      description: data['Description'] ?? '',
                      tags: List<String>.from(data['Tags'] ?? []),
                      timestamp: (data['Timestamp'] as Timestamp?)?.toDate() ??
                          DateTime.now(),
                      uid: data['Uid'] ?? '',
                      docid: data['docId'] ?? '',
                      replies: [],
                    );
                  },
                );
              },
            ),
          ),
        ]));
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
        return userDoc['XP'];
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
    String? code;
    return Card(
        child: InkWell(
            onTap: () {
              // Logic to handle card click, for example, navigating to a discussion detail screen
              Get.to(detail_discussion(docId: widget.docid,creatorId: widget.uid,));
            },
            child: Padding(
              padding:  EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Row (Profile Picture and Username)
                  Row(
                    // mainAxisAlignment: Maina,
                    children: [
                      FutureBuilder<String?>(
                          future: _fetchUserProfileImage(widget.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return  CircleAvatar(
                                backgroundColor: Colors.grey,
                              );
                            } else if (snapshot.hasError) {
                              print(snapshot.error);
                              return  CircleAvatar(
                                foregroundImage: NetworkImage(
                                  'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                                ),
                              );
                            } else {
                              return CircleAvatar(
                                foregroundImage: NetworkImage(snapshot.data!),
                              );
                            }
                          }),
                       SizedBox(width: 8), // Space between avatar and text
                      // Fetch and display the user's name
                      // if (!isFetchingUserName)
                      FutureBuilder<String?>(
                        future: _userNameFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return  Text('Loading...');
                          } else if (snapshot.hasError) {
                            return  Text('Error fetching user name');
                          } else if (snapshot.hasData) {
                            String userName = "~ ${snapshot.data}";
                            return Text(userName);
                          } else {
                            return  Text('User not found');
                          }
                        },
                      ),
                      Spacer(),
                      FutureBuilder<String?>(
                        future: _fetchUserXP(widget.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return  Text('XP: Loading...');
                          } else if (snapshot.hasError) {
                            return  Text('Error fetching XP');
                          } else if (snapshot.hasData) {
                            Object xp = snapshot.data ?? 0;
                            return Container(
                              padding:  EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.lightBlueAccent, // Light blue
                                    Colors.blue, // Regular blue
                                    Colors.blueAccent, // Darker blue
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(4, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'XP: $xp',
                                    style:  TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return  Text('XP: 0');
                          }
                        },
                      ),
                    ],
                  ),
                   SizedBox(height: 16),
                  // Space between user info and title
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge,
                  ),
                   SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: _buildDescription(widget.description, theme),
                    ),
                    maxLines: 3,
                    textAlign: TextAlign.justify,
                    overflow: TextOverflow.ellipsis,
                  ),
                   SizedBox(height: 8),
                  // code = widget.code!!
                  Wrap(
                    spacing: 5,
                    children: widget.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                  color:
                                      theme.colorScheme.onSecondaryContainer),
                            ))
                        .toList(),
                  ),
                   Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          // Logic to handle like button click
                          // Update the votes count and Firestore if needed
                          // _handleLike();
                        },
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.comment_bank_rounded),
                              onPressed: () => {},
                            ),
                             SizedBox(width: 4),
                            Text('${_repliesCount}',
                                style: theme.textTheme.labelLarge),
                             SizedBox(width: 24),
                            IconButton(
                              icon: Icon(Icons.bookmark_add_outlined),
                              onPressed: () {
                                save(widget.docid);
                              },
                              // onPressed: _handleLike,
                            ),
                          ],
                        ),
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
