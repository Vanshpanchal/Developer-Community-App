import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:developer_community_app/firebase_options.dart';
import 'package:developer_community_app/wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lottie/lottie.dart';

import 'Authservice.dart';
import 'ThemeController.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GetStorage.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // final ThemeController themeController = Get.put(ThemeController());

  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        title: 'Flutter Demo',
        // theme: ThemeData(
        //   primaryColor: themeController.primaryColor.value,
        //   colorScheme: ColorScheme.light(
        //     primary: themeController.primaryColor.value,
        //   ),
        //   useMaterial3: true,
        //   visualDensity: VisualDensity.adaptivePlatformDensity,
        //   // remove allow
        //   bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        //     elevation: 8.0,
        //   ),
        //   appBarTheme: const AppBarTheme(
        //     // AppBar color
        //     elevation: 4.0, // AppBar shadow elevation
        //   ),
        // ),
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
        home: SplashScreen());
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

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to the login page after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => wrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5BC7FF), // Deep Green
                  Color(0xFF00C7FF), // Blue-Green
                  Color(0xFF005B80), // Blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Center Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie Animation
                Lottie.asset(
                  'assets/images/discussion_animation.json',
                  // Replace with your Lottie file path
                  height: 200,
                  width: 200,
                ),
                const SizedBox(height: 20),
                // Animated Text
                Text(
                  "Let's Discuss & Share",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Connecting Ideas Globally",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
