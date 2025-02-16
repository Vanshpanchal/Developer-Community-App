import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ThemeController.dart';
// import 'theme_controller.dart';

class ThemeSelectionScreen extends StatelessWidget {
  final ThemeController themeController = Get.find<ThemeController>();

  final List<Color> colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Theme Color")),
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: colors.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              themeController.changeColor(colors[index]);
              Get.back();
            },
            child: Container(
              decoration: BoxDecoration(
                color: colors[index],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black38, width: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
