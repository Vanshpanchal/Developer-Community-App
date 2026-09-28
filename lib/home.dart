import 'package:developer_community_app/Ongoing_discussion.dart';
import 'package:developer_community_app/explore.dart';
import 'package:developer_community_app/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'saved.dart';

class home extends StatefulWidget {
  const home({super.key});

  @override
  State<home> createState() => _homepageState();
}

class _homepageState extends State<home> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final controller = Get.put(navigatorcontroller());
    // The tab controller can outlive a sign-out; always start on Explore.
    controller.selectedindex.value = 0;
    _selectedIndex = controller.selectedindex.value;
    _screens = controller.screens;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<navigatorcontroller>();

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          // If not on Explore tab, navigate back to Explore tab
          setState(() {
            _selectedIndex = 0;
            controller.selectedindex.value = 0;
          });
          _pageController.jumpToPage(0);
        } else {
          // If on Explore tab, exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Disabled swipe
          children: _screens,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
              controller.selectedindex.value = index;
            });
          },
        ),
        bottomNavigationBar: Container(
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
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                controller.selectedindex.value = index;
              });
              _pageController.jumpToPage(index);
            },
            destinations: controller.navigationDestinations,
            height: 70,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
      ),
    );
  }
}

class navigatorcontroller extends GetxController {
  final Rx<int> selectedindex = 0.obs;

  List<Widget> get screens => [
        explore(),
        ongoing_discussion(),
        saved(),
        profile(),
      ];

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
