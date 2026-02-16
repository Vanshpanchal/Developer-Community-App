// NOTE: This service is disabled because home_widget package is not installed
// To enable: Add home_widget dependency to pubspec.yaml and uncomment this file

/*
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_widget/home_widget.dart';
import '../models/gamification_models.dart';
import 'gamification_service.dart';

/// Service to manage home screen widget updates
class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  final _gamificationService = GamificationService();
  final _firestore = FirebaseFirestore.instance;

  /// Update widget with current user stats
  Future<void> updateWidget() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await _updateWidgetData(
          streak: 0,
          level: 'Beginner',
          levelIcon: '🌱',
          levelColor: '4CAF50', // Green color for beginner
        );
        return;
      }

      // Get user stats
      final stats = await _gamificationService.getGamificationStats();

      // Update widget data
      await _updateWidgetData(
        streak: stats.streak.currentStreak,
        level: stats.level.name,
        levelIcon: stats.level.icon,
        levelColor: stats.level.colorValue
            .toRadixString(16)
            .substring(2), // Remove alpha channel
      );
    } catch (e) {
      print('Error updating widget: $e');
      // Update with fallback data
      await _updateWidgetData(
        streak: 0,
        level: 'Beginner',
        levelIcon: '🌱',
        levelColor: '4CAF50',
      );
    }
  }

  /// Internal method to update widget data
  Future<void> _updateWidgetData({
    required int streak,
    required String level,
    required String levelIcon,
    required String levelColor,
  }) async {
    try {
      // Save data to widget
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.saveWidgetData<String>('level', level);
      await HomeWidget.saveWidgetData<String>('levelIcon', levelIcon);
      await HomeWidget.saveWidgetData<String>('levelColor', levelColor);

      // Update widget UI
      await HomeWidget.updateWidget(
        name: 'StreakWidgetProvider', // Android
        androidName: 'StreakWidgetProvider',
        iOSName: 'StreakWidget', // iOS
      );
    } catch (e) {
      print('Error saving widget data: $e');
    }
  }

  /// Initialize widget and set up background update callback
  Future<void> initialize() async {
    try {
      // Set app group ID for iOS (you'll need to configure this in Xcode)
      await HomeWidget.setAppGroupId('group.com.devsphere.app').catchError((e) {
        print('Widget app group setup skipped: $e');
        return null;
      });

      // Initial widget update - delayed to avoid blocking
      Future.delayed(const Duration(seconds: 2), () {
        updateWidget();
      });
    } catch (e) {
      print('Error initializing widget: $e');
    }
  }

  /// Register background update callback
  static void registerBackgroundCallback() {
    HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  /// Background callback for widget interactions
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri != null) {
      // Handle widget tap - you can navigate to specific screens
      print('Widget tapped: $uri');
    }

    // Update widget with latest stats
    await HomeWidgetService().updateWidget();
  }
}
*/

// Placeholder class to prevent import errors
class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  Future<void> updateWidget() async {}
  Future<void> initialize() async {}
  static void registerBackgroundCallback() {}
}
