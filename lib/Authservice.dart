import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils/app_logger.dart';

class Authservice {
  final _auth = FirebaseAuth.instance;
  Future<void>signup(
      {required String email,
        required String password,
        required BuildContext context}) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      ScaffoldMessenger.of(context)
          .showSnackBar( SnackBar(content: Text("Successfull")));
    } on FirebaseAuthException catch (e) {
      if(e.code == 'weak-password'){
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.code)));
      }else{
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.code)));
      }
    } catch (e) {
      AppLogger.error("Signup error", e);
    }
  }
}