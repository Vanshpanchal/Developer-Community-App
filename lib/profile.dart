import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/chatbot.dart';
import 'package:developer_community_app/saved_discussion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'chat.dart';

class profile extends StatefulWidget {
  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<profile> {
  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;
  String username = '';
  String Xp = '';
  Color _selectedColor = Colors.amber; // Default color
  // final ThemeController themeController = Get.put(ThemeController());

// Get instance of ThemeController

  @override
  void initState() {
    super.initState();
    fetchuser();
    loadimage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchuser();
  }

  signout() async {
    await FirebaseAuth.instance.signOut();
  }

  forget() async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user!.email.toString());
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.code)));
    } catch (e) {
      debugPrint("Signupcode  {$e}");
    }
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
          imageUrl = userData['profilePicture'] ?? '';
          Xp = userData['XP']?? '';

        });
      } else {
        setState(() {
          username = 'No name available';
        });
      }
    }
  }
  String? imageUrl;
  final imagepicker = ImagePicker();
  bool isLoading = false;
  pickImage() async {
    XFile? res = await imagepicker.pickImage(source: ImageSource.gallery);
    if (res != null) {
      uploadProfilePic(File(res.path));
    }
  }



  uploadProfilePic(File file) async {
    try {
      // Cloudinary Upload
      String cloudName = 'dr0c1jgbe';
      String uploadPreset = 'profile_uploads';

      var url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        // Parse response
        var responseData = await http.Response.fromStream(response);
        var jsonData = json.decode(responseData.body);
        String imageUrl = jsonData['secure_url'];

        // Save URL in Firestore
        await FirebaseFirestore.instance
            .collection('User')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .update({'profilePicture': imageUrl});

        // Update UI
        setState(() {
          this.imageUrl = imageUrl;
        });

        Get.showSnackbar(GetSnackBar(
          title: "Success",
          message: "Profile Picture Updated",
          icon: Icon(Icons.check_circle, color: Colors.green),
          duration: Duration(seconds: 2),
        ));
      } else {
        print('Failed to upload image to Cloudinary');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      Get.showSnackbar(GetSnackBar(
        title: "Error",
        message: "Failed to upload image",
        icon: Icon(Icons.error, color: Colors.red),
        duration: Duration(seconds: 2),
      ));
    }
  }

  loadimage() async {

    //
    // imageUrl = await reference.getDownloadURL();
    // setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var usercredential = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Section with Gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlue],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: imageUrl == null
                      ? CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage('https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg'),
                  )
                      : CircleAvatar(
                    radius: 60,
                    foregroundImage: NetworkImage(imageUrl!),
                  ),
                ),
                SizedBox(height: 10),
                // Username
                Text(
                  '$username',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  usercredential?.email ?? 'No User Found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Points Badge Section
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.blueAccent.shade200, Colors.lightBlue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Trophy Icon with Glow
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.yellowAccent.shade400, Colors.orange],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                SizedBox(width: 20),

                // Points and Badge Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Congratulations !!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellowAccent.shade200,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Points
                      Text(
                        'You’ve earned $Xp Points ⭐',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Action Buttons
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildProfileButton(
                  icon: Icons.forum,
                  title: 'Saved Discussion',
                  color: Colors.green,
                  // onTap: ()=>{},
                  onTap: () {Get.to(saved_discussion());},
                ),
                buildProfileButton(
                  icon: Icons.smart_toy,
                  title: 'Gemini Assistant',
                  color: Colors.purple,
                  onTap: () {
                    Get.to(ChatScreen1());
                  },
                ),
                buildProfileButton(
                  icon: Icons.edit,
                  title: 'Change Profile Picture',
                  color: Colors.blue,
                  onTap: pickImage, // Open gallery
                ),
                buildProfileButton(
                  icon: Icons.lock,
                  title: 'Reset Password',
                  color: Colors.orange,
                  onTap: () {
                    forget();
                  },
                ),
                buildProfileButton(
                  icon: Icons.logout,
                  title: 'Logout',
                  color: Colors.red,
                  onTap: () {
                    signout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          elevation: 2,
          shadowColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  uploadProfilePicFirebase(File file) async {
    try {
      Reference reference = FirebaseStorage.instance
          .ref('/Profile')
          .child('${FirebaseAuth.instance.currentUser?.uid}.png');

      await reference.putFile(file).whenComplete(() => {
        Get.showSnackbar(GetSnackBar(
          title: "Success",
          message: "Profile Pic Changed",
          icon: Icon(
            Icons.bookmark,
            color: Colors.green,
          ),
          mainButton: TextButton(
              onPressed: () {},
              child: Text(
                'Ok',
                style: TextStyle(color: Colors.white),
              )),
          duration: Duration(seconds: 2),
        ))
      });

      imageUrl = await reference.getDownloadURL();
      setState(() {});
    } catch (e) {
      print('Error');
    }
  }

}


