import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/app_update_policy.dart';
import '../../application/android_in_app_update_service.dart';
import '../../../../utils/app_logger.dart';

class AndroidUpdateGate extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget child;

  const AndroidUpdateGate({
    super.key,
    this.navigatorKey,
    required this.child,
  });

  @override
  State<AndroidUpdateGate> createState() => _AndroidUpdateGateState();
}

class _AndroidUpdateGateState extends State<AndroidUpdateGate> with WidgetsBindingObserver {
  final _updateService = AndroidInAppUpdateService();
  int? _availableVersionCode;
  bool _dialogShowing = false;
  DateTime? _lastCheckTime;
  Timer? _startupTimer;
  bool _updateRequired = false;

  bool get _isSimulatedUpdateEnabled =>
      const bool.fromEnvironment('SIMULATE_UPDATE', defaultValue: false) ||
      String.fromEnvironment('SIMULATE_UPDATE') == 'true';

  bool get shouldCheckAndroidUpdates =>
      (_isSimulatedUpdateEnabled || (!kIsWeb && kReleaseMode && Platform.isAndroid));

  @override
  void initState() {
    super.initState();
    if (shouldCheckAndroidUpdates) {
      WidgetsBinding.instance.addObserver(this);
      _scheduleStartupCheck();
    }
  }

  @override
  void dispose() {
    if (shouldCheckAndroidUpdates) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _startupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && shouldCheckAndroidUpdates) {
      _handleResumeCheck();
    }
  }

  void _scheduleStartupCheck() {
    _startupTimer = Timer(AppUpdatePolicy.startupCheckDelay, () {
      _evaluateUpdateFlow(_updateService);
    });
  }

  void _handleResumeCheck() {
    final now = DateTime.now();
    if (_lastCheckTime != null &&
        now.difference(_lastCheckTime!) < AppUpdatePolicy.minimumCheckInterval) {
      return;
    }
    Future.delayed(AppUpdatePolicy.resumeCheckDelay, () {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        _evaluateUpdateFlow(_updateService);
      }
    });
  }

  Future<bool> _openPlayStore() async {
    // Call launchUrl directly: canLaunchUrl returns false on Android 11+
    // unless the scheme is declared in <queries>.
    for (final url in [AppUpdatePolicy.playStoreMarketUrl, AppUpdatePolicy.playStoreUrl]) {
      try {
        if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (e) {
        AppLogger.error('Failed to open $url: $e', null, null, 'InAppUpdate');
      }
    }
    return false;
  }

  /// Whether the installed build is older than `Config/app.minSupportedVersionCode`.
  /// Any failure (offline, missing doc) means "not required".
  Future<bool> _isBelowMinimumVersion() async {
    try {
      final config = await FirebaseFirestore.instance
          .collection('Config')
          .doc('app')
          .get();
      final minimum = config.data()?['minSupportedVersionCode'];
      if (minimum is! int) return false;
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      return current < minimum;
    } catch (e) {
      AppLogger.warning('Minimum version check failed: $e', 'InAppUpdate');
      return false;
    }
  }

  /// Starts the Play in-app update flow, falling back to the store listing.
  Future<void> _startUpdate() async {
    try {
      await _updateService.performImmediateUpdate();
    } catch (e) {
      AppLogger.error('In-app update unavailable, opening Play Store: $e', null, null, 'InAppUpdate');
      final opened = await _openPlayStore();
      if (!opened) {
        AppLogger.warning('Could not open the Play Store listing.', 'InAppUpdate');
      }
    }
  }

  Future<void> _evaluateUpdateFlow(AndroidInAppUpdateService service) async {
    _lastCheckTime = DateTime.now();
    final result = await service.checkForUpdate();

    if (!mounted) return;

    if (!result.supportedPlatform) {
      AppLogger.debug(
        'Play Core updates are disabled because the current platform is not Android.',
        'InAppUpdate',
      );
      return;
    }

    // Store version code for skip-persistence
    _availableVersionCode = result.availableVersionCode;

    // A forced update happens only when this build is below the minimum set
    // in Config/app. Anything else stays optional.
    final required = result.isUpdateAvailable && await _isBelowMinimumVersion();
    if (!mounted) return;
    if (required != _updateRequired) setState(() => _updateRequired = required);
    if (required) return;

    // Check if user already skipped this version
    if (_availableVersionCode != null &&
        await _isVersionSkipped(_availableVersionCode!)) {
      AppLogger.info(
        'Skipping update prompt for version $_availableVersionCode (user dismissed previously).',
        'InAppUpdate',
      );
      return;
    }

    // Updates are always optional. Play reports `immediateUpdateAllowed` for
    // most available updates, so it must not be used as a "force" signal —
    // doing so locked every user out on each release.
    if (result.isUpdateAvailable) {
      if (_isSimulatedUpdateEnabled) {
        await _showSimulatedUpdateDialog(service);
        return;
      }
      AppLogger.info(
        'Play Core reports update available (versionCode=${result.availableVersionCode}), showing update dialog.',
        'InAppUpdate',
      );
      await _showPlayStoreUpdateDialog();
      return;
    }

    if (result.failureReason != null) {
      AppLogger.debug(
        'Play Core update check finished without an actionable update: ${result.failureReason}',
        'InAppUpdate',
      );
    }
  }

  Future<void> _showPlayStoreUpdateDialog() async {
    if (!mounted || _dialogShowing) return;

    final navigatorState = widget.navigatorKey?.currentState ?? Navigator.of(context);
    final overlayState = navigatorState.overlay;
    if (overlayState == null) return;

    _dialogShowing = true;

    final completer = Completer<void>();

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        return Material(
          color: Colors.black54,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App logo/icon
                          Image.asset(
                            'assets/images/QA.png',
                            height: 64,
                            width: 64,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.system_update_alt,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Update Available',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'A new version of DevSphere is available on the Play Store. Update now to get the latest features and improvements.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                _dismissOverlay(overlayEntry, completer);
                                await _startUpdate();
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Update Now',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              _skipCurrentVersion();
                              _dismissOverlay(overlayEntry, completer);
                            },
                            child: const Text('Later'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);
    await completer.future;
  }

  void _dismissOverlay(OverlayEntry entry, Completer<void> completer) {
    entry.remove();
    if (!completer.isCompleted) completer.complete();
    _dialogShowing = false;
  }

  Future<void> _skipCurrentVersion() async {
    if (_availableVersionCode == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('skipped_update_version', _availableVersionCode!);
      AppLogger.info(
        'User skipped update for version $_availableVersionCode.',
        'InAppUpdate',
      );
    } catch (e) {
      AppLogger.error('Failed to save skip version', e, null, 'InAppUpdate');
    }
  }

  Future<bool> _isVersionSkipped(int versionCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getInt('skipped_update_version');
      return skipped == versionCode;
    } catch (e) {
      AppLogger.error('Failed to check skip version', e, null, 'InAppUpdate');
      return false;
    }
  }

  Future<void> _showSimulatedUpdateDialog(AndroidInAppUpdateService service) async {
    AppLogger.info(
      'DEV: Showing simulated Play Store update dialog (SIMULATE_UPDATE=true).',
      'InAppUpdate',
    );
    await _showPlayStoreUpdateDialog();
  }

  @override
  Widget build(BuildContext context) {
    if (!_updateRequired) return widget.child;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_alt,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Update required',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'This version of DevSphere is no longer supported. Please update to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _startUpdate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Update now'),
                ),
                TextButton(
                  onPressed: _openPlayStore,
                  child: const Text('Open Play Store'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
