class AppUpdatePolicy {
  AppUpdatePolicy._();

  /// Delay before the first Play Core update check runs after startup.
  static const Duration startupCheckDelay = Duration(milliseconds: 2200);

  /// Debounce applied when the app resumes from the background.
  static const Duration resumeCheckDelay = Duration(seconds: 2);

  /// Minimum gap between successful update checks.
  static const Duration minimumCheckInterval = Duration(minutes: 15);

  // ── NEW: Play Store constants ──────────────────────────────────────

  /// Google Play Store package ID for this app.
  static const String playStoreAppId = 'com.adrenalinq.organizer';

  /// Play Store listing URL (web fallback).
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$playStoreAppId';

  /// Play Store deep link — opens the Play Store app directly.
  static const String playStoreMarketUrl =
      'market://details?id=$playStoreAppId';
}
