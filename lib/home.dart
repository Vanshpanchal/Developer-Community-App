import 'package:developer_community_app/Ongoing_discussion.dart';
import 'package:developer_community_app/explore.dart';
import 'package:developer_community_app/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'saved.dart';

class home extends StatefulWidget {
  const home({super.key});

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
    final adminEmails = ['acc.studies.123@gmail.com', 'superadmin@example.com'];

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

  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(navigatorcontroller(userRole: userRole));

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: controller.screens,
        onPageChanged: (index) {
          controller.selectedindex.value = index;
        },
      ),
      bottomNavigationBar: Obx(() => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: controller.selectedindex.value,
              onDestinationSelected: (index) {
                controller.selectedindex.value = index;
                _pageController.jumpToPage(index);
              },
              destinations: controller.navigationDestinations,
              height: 70,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
          )),
    );
  }
}

class navigatorcontroller extends GetxController {
  final Rx<int> selectedindex = 0.obs;
  final String userRole;

  navigatorcontroller({required this.userRole});

  List<Widget> get screens {
    if (userRole == 'admin') {
      return [
        explore(),
        ongoing_discussion(),
        saved(),
        profile(),
      ];
    } else {
      return [
        explore(),
        ongoing_discussion(),
        saved(),
        profile(),
      ];
    }
  }

  List<NavigationDestination> get navigationDestinations {
    return const [
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore_rounded),
        label: "Explore",
      ),
      NavigationDestination(
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum_rounded),
        label: "Discuss",
      ),
      NavigationDestination(
        icon: Icon(Icons.bookmark_outline_rounded),
        selectedIcon: Icon(Icons.bookmark_rounded),
        label: "Saved",
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: "Profile",
      ),
    ];
  }

  String getAppBarTitle() {
    switch (selectedindex.value) {
      case 0:
        return 'Explore';
      case 1:
        return 'Discussion';
      case 2:
        return 'Saved';
      case 3:
        return 'Profile';
      default:
        return 'DevSphere';
    }
  }
}
