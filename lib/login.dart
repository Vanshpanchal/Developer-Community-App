import 'package:developer_community_app/signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';

import 'home.dart';
class login extends StatelessWidget {
  final TextEditingController email_controller = TextEditingController();
  final TextEditingController password_controller = TextEditingController();
  bool _isPasswordVisible = false;
  Userlogin() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email_controller.text, password: password_controller.text);
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

  Forgetpassword() async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email_controller.text);
      Get.showSnackbar(GetSnackBar(
        title: "Success",
        message: "Password reset email sent successfully!",
        icon: Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
        backgroundColor: Get.context?.theme.colorScheme.primary ?? Colors.black,
        duration: const Duration(seconds: 3),
      ));
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
    }
    catch (e) {
      debugPrint("Signupcode  {$e}");
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.0),
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
              SizedBox(height: 10.0),
              TextButton(
                onPressed: () {Forgetpassword();},
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () {
                  Userlogin();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 15.0,horizontal: 120.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text('Login',style: const TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 20.0),
              TextButton(
                onPressed: () {
                  Get.to(signup());
                },
                child: Text("Don't have an account? Sign up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}