import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'ai_service.dart';

class attachcode extends StatefulWidget {
  final String docId;
  final String discussionId;
  attachcode({super.key, required this.docId, required this.discussionId});

  @override
  State<attachcode> createState() => _attachcodeState();
}

class _attachcodeState extends State<attachcode> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _markdownController =
      TextEditingController(); // Controller for the code field
  late var reply = "";
  String markdownContent = ''; // Markdown content for Preview
  String code = ''; // Code content to show in the 'Code' tab
  String? _aiReview; // AI generated code review
  bool _reviewLoading = false;

  String? selectedSubject;
  sharepost() async {
    try {
      // Get the current user
      var user = FirebaseAuth.instance.currentUser;

      // Trim and validate inputs
      String title = _titleController.text.trim();
      String description = _descriptionController.text.trim();

      if (title.isEmpty || description.isEmpty || _tags.isEmpty) {
        // Show error if any field is empty
        Get.showSnackbar(GetSnackBar(
          title: "Error",
          message: "All fields must be filled!",
          icon: Icon(
            Icons.error,
            color: Colors.redAccent,
          ),
          duration: Duration(seconds: 3),
        ));
        return;
      }

      // Generate document ID
      String docId = FirebaseFirestore.instance.collection('Explore').doc().id;

      // Prepare data to be stored
      Map<String, dynamic> data = {
        'Title': title.capitalizeFirst,
        'Description': description.capitalizeFirst,
        'Uid': user?.uid,
        'Report': false,
        'Tags': _tags,
        'uid': user?.uid,
        'code': code,
        'docId': docId,
        'likescount': 0,
        'likes': [],
        'Timestamp': FieldValue.serverTimestamp(),
      };

      // Add data to Firestore
      await FirebaseFirestore.instance
          .collection("Explore")
          .doc(docId)
          .set(data)
          .then((_) {
        debugPrint("AddUser: User Added");
        Get.showSnackbar(GetSnackBar(
          title: "Post Created",
          message: "Success",
          icon: Icon(
            Icons.cloud_done_sharp,
            color: Colors.white,
          ),
          duration: Duration(seconds: 3),
        ));
      }).catchError((e) {
        debugPrint("AddUser  {$e}");
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.code)));
    } catch (e) {
      debugPrint("Sharepost  {$e}");
    }
  }

  // sharepost() async {
  //   try {
  //     String title = _titleController.text.trim();
  //     String description = _descriptionController.text.trim();
  //
  //     if (title.isEmpty || description.isEmpty || _tags.isEmpty) {
  //       // Show error if any field is empty
  //       Get.showSnackbar( GetSnackBar(
  //         title: "Error",
  //         message: "All fields must be filled!",
  //         icon: Icon(
  //           Icons.error,
  //           color: Colors.white,
  //         ),
  //         duration: Duration(seconds: 3),
  //       ));
  //       return;
  //     }
  //     var user = FirebaseAuth.instance.currentUser;
  //     String doc_id =
  //         FirebaseFirestore.instance.collection('Explore').doc().id;
  //     Map<String, dynamic> Data = {
  //       'Title': _titleController.text.trim().capitalizeFirst,
  //       'Description': _descriptionController.text.trim().capitalizeFirst,
  //       'Uid': user?.uid,
  //       'Report': false,
  //       'Tags': _tags,
  //       'uid': user?.uid,
  //       'code' : code,
  //       'docId' : doc_id,
  //       'likescount': 0,
  //       'likes': [],
  //       'Timestamp': FieldValue.serverTimestamp()
  //     };
  //     await FirebaseFirestore.instance
  //         .collection("Explore")
  //         .doc(doc_id)
  //         .set(Data)
  //         .then((_) => {
  //               debugPrint("AddUser: User Added"),
  //               Get.showSnackbar( GetSnackBar(
  //                 title: "Post Created",
  //                 message: "Success",
  //                 icon: Icon(
  //                   Icons.cloud_done_sharp,
  //                   color: Colors.white,
  //                 ),
  //                 duration: Duration(seconds: 3),
  //               ))
  //             })
  //         .catchError((e) {
  //       debugPrint("AddUser  {$e}");
  //     });
  //   } on FirebaseAuthException catch (e) {
  //     ScaffoldMessenger.of(context)
  //         .showSnackBar(SnackBar(content: Text(e.code)));
  //   } catch (e) {
  //     debugPrint("Sharepost  {$e}");
  //   }
  // }

  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];

  // ignore: unused_element
  void _addTag() {
    final tag = _tagController.text.toUpperCase().trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
      print(_tags);
      _tagController.clear();
    }
  }

  // ignore: unused_element
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _fetchDocumentData() async {
    try {
      // Access the reply document from the subcollection
      print(widget.discussionId);
      print(widget.docId);
      var docRef = FirebaseFirestore.instance
          .collection('Discussions')
          .doc(widget.discussionId)
          .collection('Replies')
          .doc(widget.docId); // replyId from replyData

      DocumentSnapshot docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Retrieve the fields from the reply document
        var data = docSnapshot.data() as Map<String, dynamic>;

        // Populate the text controllers with the fetched data
        _markdownController.text = data['code'] ?? ''; // Fetch 'code' field
        _descriptionController.text = data['reply']; // Fetch 'title' field
      } else {
        // Handle the case where the document does not exist
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reply not found')),
        );
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  // Function to update the 'code' field in the reply document
  Future<void> _updateCode() async {
    try {
      // Access the reply document from the subcollection
      var docRef = FirebaseFirestore.instance
          .collection('Discussions')
          .doc(widget.discussionId)
          .collection('Replies')
          .doc(widget.docId); // replyId from replyData

      // Update the 'code' and 'title' fields in the reply document
      await docRef.update({
        'code':
            _markdownController.text, // Optionally, update the 'title' field
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code updated successfully')),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating code: $e')),
      );
    }
  }

  Future<void> _generateAIReview() async {
    if (code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add code before requesting review.')),
      );
      return;
    }
    setState(() {
      _reviewLoading = true;
      _aiReview = null;
    });
    try {
      final review = await AIService().reviewCode(
        code: code,
        context: _descriptionController.text,
      );
      if (review == AIService.missingKeyMessage) {
        if (mounted) _showMissingKeyDialog();
      } else {
        setState(() {
          _aiReview = review;
        });
      }
    } catch (e) {
      setState(() {
        _aiReview = 'Failed to generate review: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _reviewLoading = false;
        });
      }
    }
  }

  void _showMissingKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key Required'),
        content: const Text(
            'To use AI reviews, please add your Gemini API key in settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchDocumentData(); // Fetch the document data when the screen is initialized
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attach Code'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: Form(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.secondary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.code_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Attach code to enhance your discussion reply",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Code Section
                Text(
                  'Code',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DefaultTabController(
                    length: 3, // Code / Preview / Review
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: TabBar(
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor:
                                theme.colorScheme.onSurfaceVariant,
                            indicatorColor: theme.colorScheme.primary,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(icon: Icon(Icons.code), text: 'Code'),
                              Tab(
                                  icon: Icon(Icons.visibility),
                                  text: 'Preview'),
                              Tab(icon: Icon(Icons.reviews), text: 'AI Review'),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              // Code Tab
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[50],
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                ),
                                child: TextField(
                                  controller: _markdownController,
                                  maxLines: null,
                                  expands: true,
                                  decoration: const InputDecoration(
                                    hintText: '// Enter your code here...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  onChanged: (text) {
                                    setState(() {
                                      code = text;
                                    });
                                  },
                                ),
                              ),

                              // Preview Tab
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: code.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(height: 80),
                                              Icon(
                                                Icons.code_off,
                                                size: 48,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'No code to preview',
                                                style: TextStyle(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : MarkdownBody(
                                          data: "```\n$code\n```",
                                          styleSheet: MarkdownStyleSheet(
                                            code: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 14,
                                              backgroundColor:
                                                  Colors.transparent,
                                            ),
                                            codeblockDecoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey[900]
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            codeblockPadding:
                                                const EdgeInsets.all(12),
                                          ),
                                        ),
                                ),
                              ),

                              // Review Tab
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: _reviewLoading
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : _aiReview == null
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme
                                                          .primaryContainer,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.auto_fix_high,
                                                      size: 32,
                                                      color: theme.colorScheme
                                                          .onPrimaryContainer,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'AI Code Review',
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Get instant feedback on your code',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  ElevatedButton.icon(
                                                    onPressed: code.isEmpty
                                                        ? null
                                                        : _generateAIReview,
                                                    icon: const Icon(
                                                        Icons.psychology),
                                                    label: const Text(
                                                        'Generate Review'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 24,
                                                        vertical: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.psychology,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            'AI Code Review',
                                                            style: theme
                                                                .textTheme
                                                                .titleSmall
                                                                ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            'Refresh review',
                                                        onPressed:
                                                            _generateAIReview,
                                                        icon: Icon(
                                                          Icons.refresh,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      _aiReview!,
                                                      style: theme
                                                          .textTheme.bodyMedium,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                const SizedBox(height: 32),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (code.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Please add some code before attaching'),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                        return;
                      }
                      _updateCode();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text(
                      'Attach Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                if (!_reviewLoading && code.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _generateAIReview,
                      icon: const Icon(Icons.psychology),
                      label: const Text('Get AI Review'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
