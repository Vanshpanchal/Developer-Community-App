import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/addpost.dart';
import 'package:developer_community_app/chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class explore extends StatefulWidget {
  const explore({super.key});

  @override
  exploreState createState() => exploreState();
}

class exploreState extends State<explore> {
  final user = FirebaseAuth.instance.currentUser;
  TextEditingController search_controller = TextEditingController();

  String username = '';
  String imageUrl = '';

  // Sample static data
  var exploreStream = FirebaseFirestore.instance
      .collection('Explore')
      .where('Report', isEqualTo: false)
      .snapshots();

  void openbottmsheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (ctx) => addpost());
  }

  onSearch(String msg) {
    if (msg.isNotEmpty) {
      setState(() {
        exploreStream = FirebaseFirestore.instance
            .collection('Explore')
            .where("Tags", arrayContains: msg.toUpperCase())
            .snapshots();
      });
    } else if (msg.isEmpty) {
      setState(() {
        exploreStream = FirebaseFirestore.instance
            .collection('Question-Answer')
            .where('Report', isEqualTo: false)
            .snapshots();
      });
    }
    // print(exploreStream.toString());
  }

  onSearch2(String msg) {
    if (msg.isNotEmpty) {
      // if(selectedSubject!.isNotEmpty){
      setState(() {
        exploreStream = FirebaseFirestore.instance
            .collection('Explore')
            .where("Title", isGreaterThanOrEqualTo: msg.capitalizeFirst)
            .where("Title", isLessThan: '${msg.capitalizeFirst}z')
            .snapshots();
      });
    } else {
      setState(() {
        exploreStream = FirebaseFirestore.instance
            .collection('Question-Answer')
            .where('Report', isEqualTo: false)
            .snapshots();
      });
    }
    // print(exploreStream.toString());
  }

  all() {
    setState(() {
      exploreStream = FirebaseFirestore.instance
          .collection('Explore')
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
          actions: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(

                radius: 16,
                // Adjust size as needed
                backgroundImage: imageUrl != null
                    ? NetworkImage(imageUrl)
                    : AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
                // Default image
                child: imageUrl == null
                    ? Icon(Icons.account_circle,
                        size: 32) // Default icon if no profile picture
                    : null,
              ),
            )
          ],
        ),
        // floatingActionButton: FloatingActionButton(
        //   onPressed: () {
        //     Get.to(addpost());
        //   },
        //   tooltip: 'Ask Question',
        //   child: Icon(Icons.add),
        // ),
        floatingActionButton: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                  Get.to(ChatScreen1());
                  // First FAB action
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                heroTag: "fab1",
                mini: true,
                child: Icon(Icons.smart_toy,color: Colors.white), // Ensure unique heroTag
              ),
            ),
            Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    // Second FAB action
                    Get.to(addpost());
                  },
                  heroTag: "fab2",
                  tooltip: 'Ask Question',
                  child: Icon(Icons.add),
                )),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CupertinoSearchTextField(
              onSuffixTap: () => {all()},
              controller: search_controller,
              placeholder: "Search",
              onChanged: (val) => {onSearch2(val), print(val)},
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: exploreStream,
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
                    return QuestionCard(
                      title: data['Title'] ?? '',
                      description: data['Description'] ?? '',
                      tags: List<String>.from(data['Tags'] ?? []),
                      votes: data['likescount'] ?? 0,
                      answers: data['answers'] ?? 0,
                      timestamp: (data['Timestamp'] as Timestamp?)?.toDate() ??
                          DateTime.now(),
                      code: data['code'] ?? '',
                      uid: data['Uid'] ?? '',
                      docid: data['docId'] ?? '',
                    );
                  },
                );
              },
            ),
          ),
        ]));
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
    _checkIfLiked();
    // Access the parameters with widget.parameterName
  }

  Future<void> _checkIfLiked() async {
    try {
      DocumentReference questionRef =
          FirebaseFirestore.instance.collection('Explore').doc(widget.docid);
      DocumentSnapshot questionDoc = await questionRef.get();
      if (questionDoc.exists) {
        // Try to retrieve 'likes' as a List or default to an empty List if it's null or not a list
        var likes = questionDoc['likes'];
        if (likes is List) {
          setState(() {
            isLiked = likes.contains(FirebaseAuth.instance.currentUser
                ?.uid); // Check if the current user is in the list of likes
          });
        } else {
          // Handle case when 'likes' is not a List (e.g., it's a Map or another type)
          setState(() {
            isLiked =
                false; // Default to not liked if the data is not in expected format
          });
        }
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _handleLike() async {
    try {
      DocumentReference questionRef =
          FirebaseFirestore.instance.collection('Explore').doc(widget.docid);
      DocumentSnapshot questionDoc = await questionRef.get();
      if (questionDoc.exists) {
        var likes = questionDoc['likes'];

        if (isLiked) {
          // Dislike: Remove the current user's UID from the likes array
          await questionRef.update({
            'likes': FieldValue.arrayRemove(
                [FirebaseAuth.instance.currentUser?.uid]),
          });
        } else {
          // Like: Add the current user's UID to the likes array
          await questionRef.update({
            'likes':
                FieldValue.arrayUnion([FirebaseAuth.instance.currentUser?.uid]),
          });
        }

        // Fetch the updated document to get the new size of the likes array
        DocumentSnapshot updatedDoc = await questionRef.get();
        List<dynamic> updatedLikes = updatedDoc['likes'] ?? [];

        // Update the likes count based on the array size
        await questionRef.update({
          'likescount': updatedLikes.length,
        });

        setState(() {
          isLiked = !isLiked; // Toggle the like status
        });
      }
    } catch (e) {
      print('Error handling like/dislike: $e');
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
      'Saved': FieldValue.arrayUnion([itemId])
    });

    Get.showSnackbar(GetSnackBar(
      title: "Success",
      message: "Post Saved",
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
        child: Padding(
      padding: const EdgeInsets.all(16.0),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        backgroundColor: Colors.grey,
                      );
                    } else if (snapshot.hasError) {
                      print(snapshot.error);
                      return const CircleAvatar(
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
              const SizedBox(width: 8), // Space between avatar and text
              // Fetch and display the user's name
              // if (!isFetchingUserName)
              FutureBuilder<String?>(
                future: _userNameFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading...');
                  } else if (snapshot.hasError) {
                    return const Text('Error fetching user name');
                  } else if (snapshot.hasData) {
                    String userName = "~ ${snapshot.data}";
                    return Text(userName);
                  } else {
                    return const Text('User not found');
                  }
                },
              ),
              Spacer(),
              FutureBuilder<String?>(
                future: _fetchUserXP(widget.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('XP: Loading...');
                  } else if (snapshot.hasError) {
                    return const Text('Error fetching XP');
                  } else if (snapshot.hasData) {
                    Object xp = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const Text('XP: 0');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16), // Space between user info and title
          Text(
            widget.title,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: _buildDescription(widget.description, theme),
            ),
            maxLines: 10,
            textAlign: TextAlign.justify,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // code = widget.code!!
          if (widget.code != null && widget.code!.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // Background color for the body
                    padding: const EdgeInsets.all(0.0),
                    child: Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: GestureDetector(
                        onLongPress: () => {
                          Clipboard.setData(ClipboardData(text: widget.code!)),
                          Get.showSnackbar(GetSnackBar(
                            title: "Success",
                            message: "Code Copied to clipboard",
                            icon: Icon(
                              Icons.code,
                              color: Colors.green,
                            ),
                            duration: Duration(seconds: 2),
                          )),
                          // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          // content: Text('Code copied to clipboard!'),
                        },
                        child: MarkdownBody(
                          data: "```\n${widget.code}\n```",
                          styleSheet: MarkdownStyleSheet(
                            codeblockPadding: EdgeInsets.all(15),
                            code: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                              backgroundColor: Colors.transparent,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: theme.colorScheme.primaryFixed,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: theme.colorScheme.primaryFixed,
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 5,
            children: widget.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer),
                    ))
                .toList(),
          ),
          const Divider(height: 24),
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
                      icon: Icon(
                        isLiked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        color: isLiked ? Colors.blue : Colors.black,
                      ),
                      onPressed: _handleLike,
                    ),
                    const SizedBox(width: 4),
                    Text('${widget.votes}', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 24),
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
    ));
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

class SearchController extends GetxController {
  var searchText = ''.obs;

  void updateSearchText(String text) {
    searchText.value = text;
  }
}
