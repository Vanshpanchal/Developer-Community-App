import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';

class add_discussion extends StatefulWidget {
  const add_discussion({super.key});

  @override
  State<add_discussion> createState() => _add_discussionState();
}

class _add_discussionState extends State<add_discussion> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _markdownController =
  TextEditingController(); // Controller for the code field
  final _formKey = GlobalKey<FormState>();
  String markdownContent = ''; // Markdown content for Preview
  String code = ''; // Code content to show in the 'Code' tab

  String? selectedSubject;
  shareDiscussion() async {
    try {
      // Get the current user
      var user = FirebaseAuth.instance.currentUser;

      // Trim and validate inputs
      String title = _titleController.text.trim();
      String description = _descriptionController.text.trim();

      if (title.isEmpty || description.isEmpty || _tags.isEmpty) {
        // Show error if any field is empty
        Get.showSnackbar(const GetSnackBar(
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

      // Generate document ID for the discussion
      String docId = FirebaseFirestore.instance.collection('Discussions').doc().id;

      // Prepare data to be stored
      Map<String, dynamic> data = {
        'Title': title.capitalizeFirst,
        'Description': description.capitalizeFirst,
        'Uid': user?.uid,
        'Report': false,
        'Tags': _tags,
        'docId': docId,
        'Timestamp': FieldValue.serverTimestamp(),
        'Replies': [],  // Initialize an empty array for replies
      };

      // Add data to Firestore for the discussion
      await FirebaseFirestore.instance
          .collection("Discussions")
          .doc(docId)
          .set(data)
          .then((_) {
        debugPrint("Discussion Created");
        Get.showSnackbar(const GetSnackBar(
          title: "Discussion Created",
          message: "Success",
          icon: Icon(
            Icons.cloud_done_sharp,
            color: Colors.white,
          ),
          duration: Duration(seconds: 3),
        ));
      }).catchError((e) {
        debugPrint("ShareDiscussion Error: {$e}");
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.code)));
    } catch (e) {
      debugPrint("ShareDiscussion Error: {$e}");
    }
  }


  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];

  void _addTag() {
    final tag = _tagController.text.toUpperCase().trim();
    if (tag!.isNotEmpty && !_tags.contains(tag)) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Express Yourself'),
      ),
      body:
      Form(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Add your thoughts or Knowledge Resource to the Community.....",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,

                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  SizedBox(height: 20),


                  TextField(
                    controller: _titleController,
                    maxLength: null,
                    maxLines: 3,
                    enabled: true,
                    minLines: 1,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.title_rounded,color:Theme.of(context).colorScheme.primary),
                      hintText: 'Title',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 12,
                    minLines: 1,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      hintText: 'description',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.transparent,
                      prefixIcon: Icon(Icons.question_answer_outlined,color:Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    textCapitalization: TextCapitalization.characters,
                    controller: _tagController,
                    maxLines: 12,
                    minLines: 1,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add_box_rounded,color:Theme.of(context).colorScheme.primary),
                        onPressed: () {
                          _addTag();
                          print(_tags);
                        },
                      ),
                      hintText: 'Tag',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.transparent,
                      prefixIcon: Icon(Icons.tag_rounded,color:Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  Wrap(
                    spacing: 8.0,
                    children: _tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        onDeleted: () => _removeTag(tag),
                        deleteIcon: const Icon(
                          Icons.cancel_outlined,
                          size: Checkbox.width,
                          color: Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),

                  // SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: Icon(Icons.post_add_rounded,color: Colors.white,),
                    onPressed: () {
                      shareDiscussion();
                      Navigator.pop(context);
                    },
                    label: Text('Express',style: TextStyle(color: Colors.white),),
                    style: ElevatedButton.styleFrom(elevation: 2.0, // Border color and width
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0), // Border radius
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,

                    ),
                  ),
                ],
              ),
            ),
          )),
    );
  }
}
