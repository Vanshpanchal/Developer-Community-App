import 'package:flutter/foundation.dart';

/// Conditional logging utility for production safety.
/// Only logs in debug mode, preventing sensitive data leakage in production.
class AppLogger {
  AppLogger._();

  /// Log debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('[DEBUG] $tagStr$message');
    }
  }

  /// Log info (only in debug mode)
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('[INFO] $tagStr$message');
    }
  }

  /// Log warning (only in debug mode)
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('[WARN] $tagStr$message');
    }
  }

  /// Log error - in production, this could be sent to Crashlytics
  /// For now, only logs in debug mode
  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('[ERROR] $tagStr$message');
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('  StackTrace: $stackTrace');
      }
    }
    // TODO: In production, send to Firebase Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}
