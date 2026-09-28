import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  /// Brand blue. Dark enough for white text to meet WCAG AA (≈5.7:1);
  /// the previous default, Material blue 500, was only ≈3.1:1.
  static const Color defaultColor = Color(0xFF1565C0);
  static const int _oldDefault = 0xFF2196F3;

  var primaryColor = Rx<Color>(defaultColor);

  @override
  void onInit() {
    super.onInit();
    final int? storedColor = _box.read('primaryColor');
    if (storedColor != null && storedColor != _oldDefault) {
      primaryColor.value = Color(storedColor);
    }
  }

  void changeColor(Color color) {
    primaryColor.value = color; // Update color
    _box.write('primaryColor', color.value); // Save color as int
    update(); // Notify UI to update theme
  }
}
