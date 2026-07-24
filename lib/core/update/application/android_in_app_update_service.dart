import 'dart:io';
import 'package:in_app_update/in_app_update.dart';
import '../../../utils/app_logger.dart';

class AndroidUpdateCheckResult {
  final bool supportedPlatform;
  final bool isUpdateAvailable;
  final bool canStartImmediateUpdate;
  final int? availableVersionCode;
  final String? failureReason;

  AndroidUpdateCheckResult({
    required this.supportedPlatform,
    required this.isUpdateAvailable,
    required this.canStartImmediateUpdate,
    this.availableVersionCode,
    this.failureReason,
  });

  factory AndroidUpdateCheckResult.notSupported() {
    return AndroidUpdateCheckResult(
      supportedPlatform: false,
      isUpdateAvailable: false,
      canStartImmediateUpdate: false,
    );
  }

  factory AndroidUpdateCheckResult.failure(String reason) {
    return AndroidUpdateCheckResult(
      supportedPlatform: true,
      isUpdateAvailable: false,
      canStartImmediateUpdate: false,
      failureReason: reason,
    );
  }
}

class AndroidInAppUpdateService {
  Future<AndroidUpdateCheckResult> checkForUpdate() async {
    const isSimulated = bool.fromEnvironment('SIMULATE_UPDATE', defaultValue: false) ||
        String.fromEnvironment('SIMULATE_UPDATE') == 'true';

    if (isSimulated) {
      AppLogger.info('Simulating update check. Returning update available.', 'InAppUpdate');
      return AndroidUpdateCheckResult(
        supportedPlatform: true,
        isUpdateAvailable: true,
        canStartImmediateUpdate: true,
        availableVersionCode: 999,
      );
    }

    if (!Platform.isAndroid) {
      return AndroidUpdateCheckResult.notSupported();
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      final isAvailable = info.updateAvailability == UpdateAvailability.updateAvailable;
      final immediateAllowed = info.immediateUpdateAllowed;

      return AndroidUpdateCheckResult(
        supportedPlatform: true,
        isUpdateAvailable: isAvailable,
        canStartImmediateUpdate: immediateAllowed,
        availableVersionCode: info.availableVersionCode,
      );
    } catch (e) {
      AppLogger.error('Failed checking for Android update', e, null, 'InAppUpdate');
      return AndroidUpdateCheckResult.failure(e.toString());
    }
  }

  Future<void> performImmediateUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      AppLogger.error('Failed performing immediate update', e, null, 'InAppUpdate');
      rethrow;
    }
  }
}
