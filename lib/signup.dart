import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:developer_community_app/wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';

import 'home.dart';
import 'login.dart';

class signup extends StatelessWidget {
  final TextEditingController email_controller = TextEditingController();
  final TextEditingController password_controller = TextEditingController();
  final TextEditingController username_controller = TextEditingController();
  final bool _isPasswordVisible = false;

  Usersignup() async {
    try {
      String default_profile = "https://static.vecteezy.com/system/resources/thumbnails/009/734/564/small_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg";
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: email_controller.text, password: password_controller.text);
      Map<String, dynamic> userData = {
        'Username': username_controller.text,
        'Email': userCredential.user?.email,
        'Uid': userCredential.user?.uid,
        'profilePicture' : default_profile,
        'XP': 100,
        'Saved': []
      };
      await FirebaseFirestore.instance
          .collection("User")
          .doc(userCredential.user?.uid)
          .set(userData)
          .then((_) => {
        debugPrint("AddUser: User Added"),
        Get.showSnackbar(GetSnackBar(
          title: "User-Creation",
          message: "Success",
          icon:  Icon(
            Icons.cloud_done_sharp,
            color: Colors.white,
          ),
          backgroundColor: Get.context?.theme.colorScheme.secondary ?? Colors.black,
          duration:  Duration(seconds: 3),
        ))
      })
          .catchError((e) {
        debugPrint("AddUser  {$e}");
      });

      Get.offAll(wrapper());
    } on FirebaseAuthException catch (e) {

      Get.showSnackbar(GetSnackBar(
        title: "Error",
        message: e.code,
        icon: Icon(
          Icons.error,
          color: Colors.red,
        ),
        backgroundColor: Get.context?.theme.colorScheme.secondary ?? Colors.black,
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      debugPrint("Signupcode  {$e}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding:  EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 60.0),
              // 3D Illustration or Graphic
              Image.asset(
                'assets/images/login_illustration.png',
                height: 200.0,
                fit: BoxFit.cover,
              ),
              SizedBox(height: 30.0),
              Text(
                'Create an Account',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.0),
              TextField(

                controller: username_controller,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
              ),
              SizedBox(height: 15.0),
              TextField(
                controller: email_controller,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
              ),
              SizedBox(height: 15.0),
              TextField(
                controller: password_controller,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
              ),


              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () {
                  Usersignup();
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 120.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text('Sign Up',style:  TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 20.0),
              TextButton(
                  onPressed: (() => {Get.to(login())}),
                child: Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}