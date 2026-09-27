import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _playStoreUpdateAvailable = false;
  int? _availableVersionCode;
  bool _dialogShowing = false;
  bool _isForcedUpdateRequired = false;
  String _forcedUpdateMessage = '';
  DateTime? _lastCheckTime;
  Timer? _startupTimer;

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
    try {
      // Try deep link first (opens Play Store app directly)
      final marketUri = Uri.parse(AppUpdatePolicy.playStoreMarketUrl);
      if (await canLaunchUrl(marketUri)) {
        return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error('Failed to open market URL: $e', null, null, 'InAppUpdate');
    }
    try {
      // Fallback to web URL
      final webUri = Uri.parse(AppUpdatePolicy.playStoreUrl);
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.error('Failed to open web URL: $e', null, null, 'InAppUpdate');
    }
    return false;
  }

  void _requireUpdate({required String message}) {
    setState(() {
      _isForcedUpdateRequired = true;
      _forcedUpdateMessage = message;
    });
  }

  Future<void> _startForcedImmediateUpdate(AndroidInAppUpdateService service) async {
    try {
      await service.performImmediateUpdate();
    } catch (e) {
      AppLogger.error('Failed to perform immediate update: $e', null, null, 'InAppUpdate');
      // Fallback to opening Play Store if in-app update fails or cannot be started
      await _openPlayStore();
    }
  }

  Future<void> _evaluateUpdateFlow(AndroidInAppUpdateService service) async {
    _lastCheckTime = DateTime.now();
    final result = await service.checkForUpdate();

    if (!mounted) return;

    setState(() {
      _playStoreUpdateAvailable = result.isUpdateAvailable;
    });

    if (!result.supportedPlatform) {
      AppLogger.debug(
        'Play Core updates are disabled because the current platform is not Android.',
        'InAppUpdate',
      );
      return;
    }

    // Store version code for skip-persistence
    _availableVersionCode = result.availableVersionCode;

    // Check if user already skipped this version
    if (_availableVersionCode != null &&
        await _isVersionSkipped(_availableVersionCode!)) {
      AppLogger.info(
        'Skipping update prompt for version $_availableVersionCode (user dismissed previously).',
        'InAppUpdate',
      );
      return;
    }

    if (result.canStartImmediateUpdate) {
      if (_isSimulatedUpdateEnabled) {
        await _showSimulatedUpdateDialog(service);
        return;
      }

      // Forced immediate update via Play Core (existing flow)
      _requireUpdate(
        message: 'A new version is required. Complete the update to continue.',
      );
      await _startForcedImmediateUpdate(service);
      return;
    }

    if (result.isUpdateAvailable) {
      // Show the new Play Store dialog for optional updates
      AppLogger.info(
        'Play Core reports update available (versionCode=${result.availableVersionCode}), showing Play Store dialog.',
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
          color: Colors.black87,
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
                            'assets/images/Adrenalinq logo PNG.png',
                            height: 64,
                            width: 64,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/QA.png',
                                height: 64,
                                width: 64,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.system_update_alt,
                                    size: 64,
                                    color: Colors.blue,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Update Available',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'SFProRounded',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'A new version of Adrinolinq Community is available on the Play Store. Update now to get the latest features and improvements.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontFamily: 'SFProRounded',
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                await _openPlayStore();
                                _dismissOverlay(overlayEntry, completer);
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
    if (_isForcedUpdateRequired) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update_alt, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Critical Update Required',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _forcedUpdateMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _startForcedImmediateUpdate(_updateService),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Update Now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
