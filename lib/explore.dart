import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/addpost.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class explore extends StatefulWidget {
  const explore({super.key});

  @override
  exploreState createState() => exploreState();
}

class exploreState extends State<explore> {
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

  final List<Map<String, dynamic>> questions = [
    {
      'title': 'How to implement state management in Flutter?',
      'description':
          'https://unsplash.com/ I am new to Flutter and wondering about the best practices for state management...',
      'tags': ['flutter', 'state-management', 'dart'],
      'votes': 10,
      'answers': 5,
      'code': '''
int main() { 
print("Hello, World!");
  return 0;
}
  ''',
      'timestamp': DateTime.now(),
    },
    {
      'title': 'Understanding async/await in Dart',
      'description':
          'Can someone explain how async/await works in Dart with some examples?',
      'tags': ['dart', 'async', 'programming'],
      'votes': 15,
      'answers': 8,
      'timestamp': DateTime.now(),
      'code': ''
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Developer Community'),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              // Navigate to profile page
            },
          ),
        ],
      ),
      body: StreamBuilder(
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
                docid: data['docId']??'',
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(addpost());
        },
        tooltip: 'Ask Question',
        child: Icon(Icons.add),
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
            isLiked = likes.contains(FirebaseAuth.instance.currentUser?.uid); // Check if the current user is in the list of likes
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

        // Ensure likes is a List before modifying
        List<dynamic> likesList = [];
        if (likes is List) {
          likesList = List.from(likes); // Safely create a copy of the list
        }

        if (isLiked) {
          // Dislike: remove user from the list of likes
          likesList.remove(FirebaseAuth.instance.currentUser?.uid);
        } else {
          // Like: add user to the list of likes
          likesList.add(FirebaseAuth.instance.currentUser?.uid);
        }

        // Update Firestore with the new likes list and updated likes count
        await questionRef.update({
          'likes': likesList,
          'likescount': likesList.length, // Update the likes count
        });

        setState(() {
          isLiked = !isLiked; // Toggle the like status
        });
      }
    } catch (e) {
      print('Error handling like/dislike: $e');
    }
  }

  // Handle like/dislike action

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? code;
    return Card(
      child: InkWell(
        onTap: () {
          // Navigate to question detail
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Row (Profile Picture and Username)
              Row(
                children: [
                  CircleAvatar(
                    foregroundImage: NetworkImage(
                      'https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg',
                    ),
                  ),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // code = widget.code!!
              if (widget.code != null && widget.code!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: MarkdownBody(
                          data: "```\n${widget.code}\n```",
                          styleSheet: MarkdownStyleSheet(
                            code: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                              backgroundColor: Colors.transparent,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: theme.colorScheme.primaryFixed,
                              borderRadius: BorderRadius.circular(15),
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
                        Text('${widget.votes}',
                            style: theme.textTheme.labelLarge),
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
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchURL("https://unsplash.com/"),
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
