import 'package:flutter/foundation.dart';

/// Conditional logging utility for production safety.
/// Only logs in debug mode, preventing sensitive data leakage in production.
class AppLogger {
  AppLogger._();

  /// Log debug information (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// Log info (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// Log warning (only in debug mode)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  /// Log error - in production, this could be sent to Crashlytics
  /// For now, only logs in debug mode
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
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
