import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:developer_community_app/firebase_options.dart';
import 'package:developer_community_app/wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import 'Authservice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
          useMaterial3: true,
          visualDensity:  VisualDensity.adaptivePlatformDensity, // remove allow
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            elevation: 8.0,
          ),
          appBarTheme: const AppBarTheme(
            // AppBar color
            elevation: 4.0, // AppBar shadow elevation
          ),
        ),
        home: Splash());

  }
}
class Button extends StatelessWidget {
  // final auth = Authservice();
  const Button({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await Authservice()
              .signup(email: "abc@gmail.com", password: "", context: context);
        },
        child: const Text('Show SnackBar'),
      ),
    );
  }
}

class Splash extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
        duration: 2500,
        splashIconSize: 250,
        splash: 'assets/images/QA.png',
        nextScreen: wrapper(),
        splashTransition: SplashTransition.fadeTransition,
        backgroundColor: Colors.lightBlue.shade50);
  }
}