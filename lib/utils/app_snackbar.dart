import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Centralized snackbar utility for consistent notifications across the app.
/// Follows the design pattern established in login.dart/signup.dart.
class AppSnackbar {
  AppSnackbar._();

  /// Show a success snackbar with a green icon
  static void success(String message, {String title = 'Success'}) {
    _show(
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
    );
  }

  /// Show an error snackbar with a red icon
  static void error(String message, {String title = 'Error'}) {
    _show(
      title: title,
      message: message,
      icon: Icons.error_rounded,
      iconColor: Colors.red,
    );
  }

  /// Show an info snackbar with a blue icon
  static void info(String message, {String title = 'Info'}) {
    _show(
      title: title,
      message: message,
      icon: Icons.info_rounded,
      iconColor: Colors.blue,
    );
  }

  /// Show a warning snackbar with an amber/orange icon
  static void warning(String message, {String title = 'Warning'}) {
    _show(
      title: title,
      message: message,
      icon: Icons.warning_rounded,
      iconColor: Colors.orange,
    );
  }

  /// Internal method to display a snackbar with consistent styling
  static void _show({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.showSnackbar(GetSnackBar(
      titleText: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      icon: Icon(icon, color: iconColor),
      backgroundColor: Colors.grey[900]!,
      duration: duration,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      snackPosition: SnackPosition.TOP,
    ));
  }

  /// Custom snackbar for advanced use cases
  static void custom({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      duration: duration,
    );
  }
}
