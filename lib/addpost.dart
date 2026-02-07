import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'services/gamification_service.dart';
import 'models/gamification_models.dart';

class addpost extends StatefulWidget {
  addpost({super.key});

  @override
  State<addpost> createState() => addpostState();
}

class addpostState extends State<addpost> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _markdownController =
      TextEditingController(); // Controller for the code field
  final _formKey = GlobalKey<FormState>();
  String markdownContent = ''; // Markdown content for Preview
  String code = ''; // Code content to show in the 'Code' tab
  final _gamificationService = GamificationService();

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
          .then((_) async {
        debugPrint("AddUser: User Added");

        // Award XP for creating post
        await _gamificationService.awardXp(XpAction.createPost);
        await _gamificationService.recordActivity();

        Get.showSnackbar(GetSnackBar(
          title: "Post Created",
          message: "Success! +${XpAction.createPost.defaultXp} XP",
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

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
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
                          Icons.lightbulb_outline,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Share your knowledge and insights with the developer community",
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

                // Title Field
                Text(
                  'Title',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Enter a compelling title...',
                    prefixIcon: Icon(
                      Icons.title_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description Field
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 8,
                  minLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your post in detail...',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tags Field
                Text(
                  'Tags',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: 'Add tags (e.g., FLUTTER, DART)',
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: _addTag,
                      tooltip: 'Add tag',
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),

                // Tags Display
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _tags.map((tag) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                              theme.colorScheme.secondary
                                  .withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Chip(
                          label: Text(
                            tag,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          deleteIcon: Icon(
                            Icons.close,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          onDeleted: () => _removeTag(tag),
                          elevation: 0,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),

                // Code Section
                Text(
                  'Code Snippet (Optional)',
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
                    length: 2,
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
                              Tab(
                                icon: Icon(Icons.code),
                                text: 'Code',
                              ),
                              Tab(
                                icon: Icon(Icons.visibility),
                                text: 'Preview',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 250,
                          child: TabBarView(
                            children: [
                              // Code Tab
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
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
                                          child: Text(
                                            'No code to preview',
                                            style: TextStyle(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                              fontStyle: FontStyle.italic,
                                            ),
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
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            codeblockPadding:
                                                const EdgeInsets.all(12),
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

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_titleController.text.trim().isEmpty ||
                          _descriptionController.text.trim().isEmpty ||
                          _tags.isEmpty) {
                        Get.showSnackbar(
                          GetSnackBar(
                            title: "Missing Information",
                            message: "Please fill in all required fields",
                            icon: const Icon(Icons.error_outline,
                                color: Colors.white),
                            backgroundColor: theme.colorScheme.error,
                            duration: const Duration(seconds: 3),
                            snackPosition: SnackPosition.TOP,
                          ),
                        );
                        return;
                      }
                      sharepost();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      'Publish Post',
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
