import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/attachcode.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';

class detail_discussion extends StatefulWidget {
  final String docId;
  final String creatorId;

   detail_discussion(
      {Key? key, required this.docId, required this.creatorId});

  @override
  State<detail_discussion> createState() => _detail_discussionState();
}

class _detail_discussionState extends State<detail_discussion> {
  final _replyController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;
  String? _threadSummary;
  bool _summaryLoading = false;
  Future<void> updateXP2(String uid, int points) async {
    try {
      // Fetch the current XP value as a String
      final userDoc =
      await FirebaseFirestore.instance.collection('User').doc(uid).get();

      if (userDoc.exists) {
        // Get the current XP as a String
        String currentXPString = userDoc.data()?['XP'] ?? '0'; // Default to '0'
        int currentXP = int.tryParse(currentXPString) ?? 0; // Parse to int

        // Update XP (add or subtract points)
        int updatedXP = currentXP - points;

        // Save the updated XP back to Firestore as a String
        await FirebaseFirestore.instance.collection('User').doc(uid).update({
          'XP': updatedXP.toString(),
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
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
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
  Future<String?> _fetchUserProfileImage(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
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
          'replyId': replyDocRef.id, // Use the document ID as the replyId
          'reply': _replyController.text.trim(),
          'user_name': username,
          'profilePicture': imageUrl,
          'uid': FirebaseAuth.instance.currentUser?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'code': "",
          'accepted': false, // Set initial accepted to false
        });

        // int replies_count = getRepliesCount();
        // await FirebaseFirestore.instance.doc(widget.docId)
        //     .collection('Replies').get()
        // Clear the reply text field
        _replyController.clear();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reply added successfully!')),
        );
      } else {
        // Handle case where user document does not exist
        throw Exception('User document not found in Firestore.');
      }
    } catch (e) {
      // Print error to console
      print('Error adding reply: $e');

      // Show error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add reply: $e')),
      );
    }
  }

  Future<void> updateXP(String uid) async {
    try {
      // Fetch the current XP value as a String
      final userDoc =
          await FirebaseFirestore.instance.collection('User').doc(uid).get();

      if (userDoc.exists) {
        // Get the current XP as a String
        String currentXPString =
            userDoc.data()?['XP'] ?? '0'; // Default to '0' if XP is null
        int currentXP = int.tryParse(currentXPString) ??
            0; // Convert to int, default to 0 if parsing fails

        // Add 50 to the current XP
        int updatedXP = currentXP + 50;

        // Save the updated XP back to Firestore as a String
        await FirebaseFirestore.instance.collection('User').doc(uid).update({
          'XP': updatedXP.toString(),
        });

        print('XP updated successfully to $updatedXP!');
      } else {
        print('User document not found.');
      }
    } catch (e) {
      print('Error updating XP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text("Discussion Details"), actions: [
        IconButton(
          tooltip: 'Summarize Thread',
          icon: _summaryLoading
              ?  SizedBox(width: 20,height:20,child: CircularProgressIndicator(strokeWidth: 2))
              :  Icon(Icons.summarize),
          onPressed: _summaryLoading ? null : () async {
            setState(() { _summaryLoading = true; _threadSummary = null; });
            try {
              // Fetch discussion doc & replies once.
              final discSnap = await FirebaseFirestore.instance.collection('Discussions').doc(widget.docId).get();
              final repliesSnap = await FirebaseFirestore.instance.collection('Discussions').doc(widget.docId).collection('Replies').orderBy('timestamp').get();
              final title = discSnap.data()?['Title'] ?? 'Untitled';
              final desc = discSnap.data()?['Description'] ?? '';
              final replies = repliesSnap.docs.map((d) => d.data()).toList();
              final summary = await AIService().summarizeThread(
                title: title,
                description: desc,
                replies: replies.cast<Map<String,dynamic>>()
              );
              if (mounted) {
                setState(() { _threadSummary = summary; });
                // Show in bottom sheet
                if (summary.isNotEmpty) {
                  // ignore: use_build_context_synchronously
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: theme.colorScheme.surface,
                    shape:  RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _ThreadSummarySheet(summary: summary),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Summary failed: $e')));
              }
            } finally {
              if (mounted) setState(() { _summaryLoading = false; });
            }
          },
        ),
      ]),
      body: Padding(
        padding:  EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // StreamBuilder for Discussion Data
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Discussions')
                    .doc(widget.docId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(child: Text('Discussion not found.'));
                  }

                  var discussionData = snapshot.data!;
                  var repliesRef = FirebaseFirestore.instance
                      .collection('Discussions')
                      .doc(widget.docId)
                      .collection('Replies'); // The subcollection for replies

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display the discussion details in a card
                      display_discussion(
                        title: discussionData['Title'] ?? '',
                        description: discussionData['Description'] ?? '',
                        tags: List<String>.from(discussionData['Tags'] ?? []),
                        timestamp: (discussionData['Timestamp'] as Timestamp?)
                                ?.toDate() ??
                            DateTime.now(),
                        uid: discussionData['Uid'] ?? '',
                        docid: widget.docId,
                        replies: [], // You can add replies here later
                      ),
                      SizedBox(height: 16),
                      // Fetch and display replies in a ListView
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: repliesRef.orderBy('timestamp').snapshots(),
                          builder: (context, repliesSnapshot) {
                            if (repliesSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            if (repliesSnapshot.hasError) {
                              return Center(
                                  child:
                                      Text('Error: ${repliesSnapshot.error}'));
                            }
                            if (repliesSnapshot.data?.docs.isEmpty ?? true) {
                              return Center(child: Text('No replies yet.'));
                            }

                            final replies = repliesSnapshot.data!.docs;

                            return ListView.builder(
                              itemCount: replies.length,
                              itemBuilder: (context, index) {
                                var replyData = replies[index].data() as Map<String, dynamic>;

                                return GestureDetector(
                                  onTap: ()async{
                                    print("hello vansh");
                                    var code = replyData['code']!!;
                                    print(code);
                                    if (code.toString().isNotEmpty) {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(
                                                24), // Rounded top corners
                                          ),
                                        ),
                                        builder: (context) {
                                          return Padding(
                                            padding: EdgeInsets.only(
                                              top: 16,
                                              left: 16,
                                              right: 16,
                                              bottom: MediaQuery.of(context).viewInsets.bottom + 16, // Adjust for keyboard visibility
                                            ),
                                            child: SizedBox(
                                              width: MediaQuery.of(context).size.width, // Full screen width
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min, // Adjusts height based on content
                                                children: [
                                                  // Heading
                                                  Text(
                                                    'Code Snippet', // Change the heading as needed
                                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(height: 8), // Spacing between heading and content

                                                  // Additional Info (can be a description or metadata)
                                                  Text(
                                                    'Description: This is a sample code snippet. Feel free to copy it and use it in your project.',
                                                    style: Theme.of(context).textTheme.bodyMedium,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(height: 16), // Spacing between description and code block

                                                  // Code Block
                                                  GestureDetector(
                                                    onLongPress: () {
                                                      Clipboard.setData(
                                                        ClipboardData(text: replyData['code'] ?? 'Sample Code Here'), // Replace with dynamic code
                                                      );
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Code Copied to Clipboard!'),
                                                          duration: Duration(seconds: 2),
                                                          backgroundColor: Colors.green,
                                                        ),
                                                      );
                                                    },
                                                    child: MarkdownBody(
                                                      data: "```\n${replyData['code'] ?? 'Sample Code Here'}\n```", // Display dynamic code block
                                                      styleSheet: MarkdownStyleSheet(
                                                        codeblockPadding: EdgeInsets.all(15),
                                                        code: TextStyle(
                                                          fontFamily: 'monospace',
                                                          fontWeight: FontWeight.normal,
                                                          fontSize: 14,
                                                          backgroundColor: Colors.transparent,
                                                        ),
                                                        blockquoteDecoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.primaryContainer,
                                                          borderRadius: BorderRadius.circular(15),
                                                        ),
                                                        codeblockDecoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.primaryContainer,
                                                          borderRadius: BorderRadius.circular(15),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 16), // Spacing between code block and button

                                                  // Close Button
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context); // Close the Bottom Sheet
                                                    },
                                                    child: Text("Close"),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );


                                        },
                                      );
                                    }
                                  },
                                  onLongPress: ()async{
                                    if (user?.uid == replyData['uid']) {
                                      bool? confirmDelete = await showDialog(
                                        barrierDismissible: false,
                                        context: context,
                                        builder: (context) =>
                                            AlertDialog(
                                              title:  Text("Delete Reply"),

                                              content:  Text(
                                                  "Are you sure you want to delete this reply?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child:  Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child:  Text("Delete"),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (confirmDelete == true) {
                                        try {
                                          // Delete the reply from Firestore
                                          await FirebaseFirestore.instance
                                              .collection('Discussions')
                                              .doc(widget.docId)
                                              .collection('Replies')
                                              .doc(replyData['replyId'])
                                              .delete();

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                             SnackBar(content: Text(
                                                'Reply deleted successfully!')),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text(
                                                'Failed to delete reply: $e'))
                                            ,
                                          );
                                          print(e);
                                        }
                                      }

                                      if (replyData['accepted'] == true) {
                                        updateXP2(replyData['uid'], 50);
                                      }
                                    }
                                  },
                                  child: Card(

                                    margin:  EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 5,
                                    child: Padding(
                                      padding:  EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Row with Circle Avatar and User Name
                                          Row(
                                            children: [
                                              FutureBuilder<String?>(
                                                  future: _fetchUserProfileImage(replyData['uid']),
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
                                               SizedBox(width: 12),
                                              // User Name
                                              Expanded(
                                                child: Text(
                                                  "~"+replyData['user_name'] ?? 'Unknown User',
                                                  style:  TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              FutureBuilder<String?>(
                                                future: _fetchUserXP(replyData['uid']),
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
                                                          horizontal: 12, vertical: 6),
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
                                           SizedBox(height: 12), // Space between Row and content

                                          RichText(
                                            text: TextSpan(
                                              style: theme.textTheme.bodyMedium,
                                              children:
                                              _buildDescription(replyData['reply'] ?? 'No reply content', theme),
                                            ),
                                            // maxLines: 10,
                                            textAlign: TextAlign.justify,
                                            // overflow: TextOverflow.ellipsis,
                                          ),
                                          // Reply Text
                                          // Text(
                                          //   replyData['reply'] ?? 'No reply content',
                                          //   style:  TextStyle(
                                          //     fontSize: 14,
                                          //     fontWeight: FontWeight.normal,
                                          //     color: Colors.black87,
                                          //   ),
                                          //   textAlign: TextAlign.justify,
                                          // ),

                                           SizedBox(height: 5),

                                          // Timestamp

                                          Row(
                                            children: [
                                              Text(
                                                "Posted on: ${DateFormat('MMM dd, yyyy').format(replyData['timestamp'].toDate())}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              if (replyData['code'].toString().isNotEmpty)
                                                IconButton(
                                                  onPressed: () {
                                                    // Your onPressed action here
                                                  },
                                                  icon: Icon(
                                                    size: 18,
                                                    Icons.attach_file,
                                                    color: Colors.blue, // Optional: icon color
                                                  ),
                                                ),
                                            ],
                                          ),

                                           SizedBox(height: 5),

                                          if (!replyData['code'].toString().isNotEmpty && replyData['uid'] == user?.uid)
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                // Your onPressed action here
                                                Get.to(() =>
                                                    attachcode(
                                                        docId: replyData['replyId'],
                                                        discussionId: widget
                                                            .docId));
                                              },
                                              icon: Icon(Icons.attach_file),
                                              label: Text('Attach Code Snippet'),
                                              // Optional, can be used if you want text with the icon
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: Colors
                                                    .blue), // Optional: color of the outline
                                              ),
                                            ),
                                              // Accepted Reply Indicator or Button

                                          if (replyData['accepted'] == true)
                                            Container(
                                              padding:
                                               EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children:  [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Accepted',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            FutureBuilder<User?>(
                                              future: FirebaseAuth.instance.authStateChanges().first,
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                  return  CircularProgressIndicator();
                                                } else if (snapshot.hasData &&
                                                    snapshot.data!.uid == widget.creatorId) {
                                                  return GestureDetector(
                                                    onTap: () async {
                                                        if (user?.uid != replyData['uid']) {
                                                          try {
                                                            await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                'Discussions')
                                                                .doc(widget.docId)
                                                                .collection(
                                                                'Replies')
                                                                .doc(
                                                                replyData['replyId'])
                                                                .update({
                                                              'accepted': true
                                                            });

                                                            updateXP(
                                                                replyData['uid']);
                                                            ScaffoldMessenger.of(
                                                                context)
                                                                .showSnackBar(
                                                               SnackBar(
                                                                  content: Text(
                                                                      'Reply accepted!')),
                                                            );
                                                          } catch (e) {
                                                            ScaffoldMessenger.of(
                                                                context)
                                                                .showSnackBar(
                                                               SnackBar(
                                                                  content: Text(
                                                                      'Failed to accept.')),
                                                            );
                                                          }
                                                        }
                                                    },
                                                    child: Container(
                                                      padding:  EdgeInsets.symmetric(
                                                          vertical: 6, horizontal: 12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children:  [
                                                          Icon(
                                                            Icons.check_circle_outline,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Accept Reply',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  return  SizedBox.shrink();
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );

                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Material 3 style reply TextField at the bottom
            Padding(
              padding:  EdgeInsets.symmetric(vertical: 0),
              child: Row(
                children: [
                  // Wrap the TextField with an Expanded widget to allow it to take up remaining space
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _replyController,
                        maxLines: 1, // Ensure the TextField doesn't overflow
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[200],
                          labelText: 'Write a reply...',
                          hintText: 'Type your reply here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () async {
                      if (_replyController.text.trim().isNotEmpty){
                      addReply();
                      }
                    },
                  ),
                ],
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

   display_discussion({
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
    // _checkIfLiked();
    // Access the parameters with widget.parameterName
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
              // Get.to(detail_discussion(docId: widget.docid));
            },
            onLongPress: () {
              // Show the description in a bottom sheet when the card is long pressed
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                // Allow content to scroll
                backgroundColor: Colors.transparent,
                // Transparent background for full-width
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16)), // Rounded corners on top
                ),
                builder: (context) {
                  return Container(
                    width: double.infinity, // Full width of the screen
                    padding:  EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      // Material 3 background color
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title of the discussion
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                         SizedBox(height: 8),
                        // Description of the discussion
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium,
                            children:
                                _buildDescription(widget.description, theme),
                          ),
                          maxLines: 10,
                          textAlign: TextAlign.justify,
                          overflow: TextOverflow.ellipsis,
                        ),
                         SizedBox(height: 16),

                        Wrap(
                          spacing: 5,
                          children: widget.tags
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    backgroundColor:
                                        theme.colorScheme.secondaryContainer,
                                    labelStyle: TextStyle(
                                        color: theme
                                            .colorScheme.onSecondaryContainer),
                                  ))
                              .toList(),
                        ),
                        // You can add more content or buttons if needed
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pop(); // Close the bottom sheet
                          },
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: Padding(
              padding:  EdgeInsets.all(10.0),
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
                       SizedBox(width: 2), // Space between avatar and text
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
                                  horizontal: 12, vertical: 6),
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
                   SizedBox(height: 6),
                  // Space between user info and title
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium,
                  ),
                   SizedBox(height: 0),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: _buildDescription(widget.description, theme),
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.justify,
                    overflow: TextOverflow.ellipsis,
                  ),
                  //  SizedBox(height: 8),
                  // code = widget.code!!
                  // Wrap(
                  //   spacing: 5,
                  //   children: widget.tags
                  //       .map((tag) => Chip(
                  //     label: Text(tag),
                  //     backgroundColor:
                  //     theme.colorScheme.secondaryContainer,
                  //     labelStyle: TextStyle(
                  //         color:
                  //         theme.colorScheme.onSecondaryContainer),
                  //   ))
                  //       .toList(),
                  // ),
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

class _ThreadSummarySheet extends StatefulWidget {
  final String summary;
   _ThreadSummarySheet({required this.summary});

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
            padding:  EdgeInsets.only(top: 12),
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
            padding:  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                 Icon(Icons.summarize),
                 SizedBox(width: 8),
                Expanded(
                  child: Text('AI Thread Summary',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
                IconButton(
                  tooltip: 'Copy Markdown',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.summary));
                    setState(() => _copied = true);
                    Future.delayed( Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Summary copied to clipboard')),
                      );
                    }
                  },
                  icon: Icon(_copied ? Icons.check : Icons.copy),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon:  Icon(Icons.close),
                ),
              ],
            ),
          ),
           Divider(height: 1),
          Expanded(
            child: AnimatedCrossFade(
              duration:  Duration(milliseconds: 250),
              crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Markdown(
                controller: scrollController,
                data: widget.summary,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h2: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
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
            padding:  EdgeInsets.fromLTRB(16,4,16,12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _expanded = true),
                  icon:  Icon(Icons.visibility),
                  label:  Text('Expand'),
                ),
                 SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.summary));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Copied')), 
                      );
                    }
                  },
                  icon:  Icon(Icons.copy_all),
                  label:  Text('Copy'),
                ),
                 Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:  Text('Done'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
