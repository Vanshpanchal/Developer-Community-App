import 'package:developer_community_app/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:developer_community_app/login.dart';
class wrapper extends StatefulWidget {
  const wrapper({super.key});

  @override
  State<wrapper> createState() => _wrapperState();
}

class _wrapperState extends State<wrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(

        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return home();
          } else {
            return login();
            //   Login
          }
        },
      ),
    );
  }
}