import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  var primaryColor = Rx<Color>(Colors.blue); // Default color

  @override
  void onInit() {
    super.onInit();
    int? storedColor = _box.read('primaryColor');
    if (storedColor != null) {
      primaryColor.value = Color(storedColor); // Convert int to Color
    }
  }

  void changeColor(Color color) {
    primaryColor.value = color; // Update color
    _box.write('primaryColor', color.value); // Save color as int
    update(); // Notify UI to update theme
  }
}
