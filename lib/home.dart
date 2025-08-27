import 'package:developer_community_app/Ongoing_discussion.dart';
import 'package:developer_community_app/chatbot.dart';
import 'package:developer_community_app/explore.dart';
import 'package:developer_community_app/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import 'chat.dart';
import 'saved.dart';


class home extends StatefulWidget {
   home({super.key});

  @override
  State<home> createState() => _homepageState();
}

class _homepageState extends State<home> {
  final user = FirebaseAuth.instance.currentUser;
  String userRole = 'User';

  signout() async {
    await FirebaseAuth.instance.signOut();
  }

  void determineUserRole() {
    final adminEmails = [
      'acc.studies.123@gmail.com',
      'superadmin@example.com'
    ]; // Add your admin emails here

    if (user != null && adminEmails.contains(user!.email)) {
      setState(() {
        userRole = 'admin';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    determineUserRole();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = Get.put(navigatorcontroller(userRole: userRole));
    return Scaffold(

      body: Obx(() => controller.screen[controller.selectedindex.value]),
      bottomNavigationBar: Obx(() => NavigationBar(
        selectedIndex: controller.selectedindex.value,
        onDestinationSelected: (index) =>
        controller.selectedindex.value = index,
        destinations: controller.navigationDestinations,
      )),
    );
  }
}


class navigatorcontroller extends GetxController {
  final Rx<int> selectedindex = 0.obs;
  final String userRole;

  navigatorcontroller({required this.userRole});

  List<Widget> get screen {
    if (userRole == 'admin') {
      return [
        explore(),
        ongoing_discussion(),
        // Container(color: Colors.black,),
        // Container(color: Colors.brown,),

        // ChatScreen1(),
         saved(),
        // ChatScreen(),
        profile(),
        //  mypost(),
        //  profile(),
        //  reported()
        // Add more admin-specific screens here
      ];
    } else {
      return [
        explore(),
        ongoing_discussion(),
        // Container(color: Colors.grey,),
        // Container(color: Colors.grey,),

        // ChatScreen1(),
         saved(),
        // ChatScreen(),
        profile(),
        // ---
        // explore(),
        // ongoing_discussion(),
        // // ChatScreen(),
        // // ChatScreen1(),
        //  saved(),
        // // ChatScreen(),
        // profile(),
        // //  saved(),
        // //  mypost(),
        // //  profile(),
      ];
    }
  }

  List<NavigationDestination> get navigationDestinations {
    if (userRole == 'admin') {
      return  [
        NavigationDestination(
            icon: Icon(Icons.looks, color: Colors.black),
            label: "Explore"),
        NavigationDestination(
            icon: Icon(Icons.forum_rounded, color: Colors.black),
            label: "Saved"),
        NavigationDestination(
            icon: Icon(Icons.book, color: Colors.black),
            label: "Saved"),
        // NavigationDestination(
        //     icon: Icon(Icons.chat_rounded, color: Colors.black),
        //     label: "Chat"),
        NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.black),
            label: "Profile"),
        NavigationDestination(
            icon: Icon(Icons.person, color: Colors.black),
            label: "Reported"),

        // Add more admin-specific navigation destinations here
      ];
    } else {
      return  [
        NavigationDestination(
            icon: Icon(Icons.looks_rounded, color: Colors.black),
            label: "Explore"),
        NavigationDestination(
            icon: Icon(Icons.forum_rounded, color: Colors.black),
            label: "Discussion"),
        NavigationDestination(
            icon: Icon(Icons.book, color: Colors.black),
            label: "Saved"),
        // NavigationDestination(
        //     icon: Icon(Icons.chat_rounded, color: Colors.black),
        //     label: "Chat"),
        NavigationDestination(
            icon: Icon(Icons.person, color: Colors.black),
            label: "Profile"),
      ];
    }
  }

  String getAppBarTitle() {
    switch (selectedindex.value) {
      case 0:
        return 'saved';
      case 1:
        return 'Discussion';
      case 2:
        return 'Saved';
      case 3:
        return 'Profile';
      default:
        return 'Reported';
    }
  }
}
