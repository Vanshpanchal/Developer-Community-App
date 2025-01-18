import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class detail_discussion extends StatefulWidget {
  final String docId;
  final String creatorId;

  const detail_discussion(
      {Key? key, required this.docId, required this.creatorId});

  @override
  State<detail_discussion> createState() => _detail_discussionState();
}

class _detail_discussionState extends State<detail_discussion> {
  final _replyController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;
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
    return Scaffold(
      appBar: AppBar(title: Text("Discussion Details")),
      body: Padding(
        padding: const EdgeInsets.all(6.0),
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
                                    if (user?.uid == replyData['uid']) {
                                      bool? confirmDelete = await showDialog(
                                        context: context,
                                        builder: (context) =>
                                            AlertDialog(
                                              title: const Text("Delete Reply"),
                                              content: const Text(
                                                  "Are you sure you want to delete this reply?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text("Delete"),
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
                                            const SnackBar(content: Text(
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
                                    
                                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
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
                                              const SizedBox(width: 12),
                                              // User Name
                                              Expanded(
                                                child: Text(
                                                  "~"+replyData['user_name'] ?? 'Unknown User',
                                                  style: const TextStyle(
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
                                                    return const Text('XP: Loading...');
                                                  } else if (snapshot.hasError) {
                                                    return const Text('Error fetching XP');
                                                  } else if (snapshot.hasData) {
                                                    Object xp = snapshot.data ?? 0;
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(
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
                                          const SizedBox(height: 12), // Space between Row and content
                                  
                                          // Reply Text
                                          Text(
                                            replyData['reply'] ?? 'No reply content',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.justify,
                                          ),
                                          const SizedBox(height: 8),
                                  
                                          // Timestamp
                                          Text(
                                            "Posted on: ${DateFormat('MMM dd, yyyy').format(replyData['timestamp'].toDate())}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                  
                                          // Accepted Reply Indicator or Button
                                          if (replyData['accepted'] == true)
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
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
                                                  return const CircularProgressIndicator();
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
                                                              const SnackBar(
                                                                  content: Text(
                                                                      'Reply accepted!')),
                                                            );
                                                          } catch (e) {
                                                            ScaffoldMessenger.of(
                                                                context)
                                                                .showSnackBar(
                                                              const SnackBar(
                                                                  content: Text(
                                                                      'Failed to accept.')),
                                                            );
                                                          }
                                                        }
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          vertical: 6, horizontal: 12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: const [
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
                                                  return const SizedBox.shrink();
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
              padding: const EdgeInsets.symmetric(vertical: 0),
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
                      addReply();
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
                    padding: const EdgeInsets.all(16.0),
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
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 16),

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
              padding: const EdgeInsets.all(10.0),
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
                      const SizedBox(width: 2), // Space between avatar and text
                      // Fetch and display the user's name
                      // if (!isFetchingUserName)
                      FutureBuilder<String?>(
                        future: _userNameFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('XP: Loading...');
                          } else if (snapshot.hasError) {
                            return const Text('Error fetching XP');
                          } else if (snapshot.hasData) {
                            Object xp = snapshot.data ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
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
                  const SizedBox(height: 6),
                  // Space between user info and title
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 0),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: _buildDescription(widget.description, theme),
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.justify,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // const SizedBox(height: 8),
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
