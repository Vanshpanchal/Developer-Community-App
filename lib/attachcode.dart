import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';

class attachcode extends StatefulWidget {
  final String docId;
  final String discussionId;
  const attachcode({super.key, required this.docId,required this.discussionId});


  @override
  State<attachcode> createState() => _attachcodeState();
}

class _attachcodeState extends State<attachcode> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _markdownController =
  TextEditingController(); // Controller for the code field
  late var reply = "";
  final _formKey = GlobalKey<FormState>();
  String markdownContent = ''; // Markdown content for Preview
  String code = ''; // Code content to show in the 'Code' tab

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
        Get.showSnackbar(const GetSnackBar(
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
  //       Get.showSnackbar(const GetSnackBar(
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
  //               Get.showSnackbar(const GetSnackBar(
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
        _descriptionController.text = data['reply'] ; // Fetch 'title' field
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
        'code': _markdownController.text,  // Optionally, update the 'title' field
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

  @override
  void initState() {
    super.initState();
    _fetchDocumentData(); // Fetch the document data when the screen is initialized
  }
  @override
  Widget build(BuildContext context) {
    return
      Scaffold(
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
                      "Attach your code...",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,

                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.justify,
                    ),

                    SizedBox(height: 20),

                    DefaultTabController(
                      length: 2, // Two tabs: one for code and one for preview
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(
                                icon: Icon(Icons.code),
                              ),
                              Tab(
                                icon: Icon(Icons.visibility),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 200, // Set height to accommodate both tabs
                            child: TabBarView(
                              children: [
                                // Code Tab: Displays the code as a TextField
                                Card(
                                  child: Padding(

                                    padding: const EdgeInsets.all(16.0),
                                    child: TextField(
                                      controller: _markdownController, // Use _codeController for TextField
                                      maxLines: null, // Allow multiple lines
                                      decoration: InputDecoration(
                                        hintText: 'Enter your code here',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                      ),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      onChanged: (text) {
                                        setState(() {
                                          code = text; // Update code with the text field input
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                // Preview Tab: Renders the Markdown content
                                Card(
                                  child : SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: MarkdownBody(
                                            data: "```\n$code\n```",
                                            styleSheet: MarkdownStyleSheet(
                                              code: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 16,
                                                  backgroundColor: Colors.transparent
                                              ),
                                              codeblockDecoration: BoxDecoration(
                                                  borderRadius:BorderRadius.circular(15)

                                              ),

                                            ),

                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.attach_file,color: Colors.white,),
                      onPressed: () {
                        _updateCode();
                        Navigator.pop(context);
                      },
                      label: Text('Attach Code',style: TextStyle(color: Colors.white),),
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
