import 'package:developer_community_app/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:developer_community_app/login.dart';

import 'services/block_service.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'utils/app_logger.dart';

class wrapper extends StatefulWidget {
  const wrapper({super.key});

  @override
  State<wrapper> createState() => _wrapperState();
}

class _wrapperState extends State<wrapper> {
  String? _bootstrappedUid;
  Future<void>? _bootstrap;

  /// Runs once per signed-in user: repairs a missing profile and registers
  /// the device for push. Failures (e.g. offline) never block the home screen.
  Future<void> _bootstrapFor(User user) {
    if (_bootstrappedUid == user.uid && _bootstrap != null) return _bootstrap!;
    _bootstrappedUid = user.uid;
    BlockService.instance.start(user.uid);
    return _bootstrap = () async {
      try {
        await SessionService.instance
            .ensureProfile(user)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        AppLogger.warning('Profile bootstrap skipped: $e');
      }
      SessionService.instance.registerFcmToken(user);
      NotificationService.instance.start();
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            _bootstrappedUid = null;
            _bootstrap = null;
            return login();
          }
          return FutureBuilder<void>(
            future: _bootstrapFor(user),
            builder: (context, bootstrap) {
              if (bootstrap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return home();
            },
          );
        },
      ),
    );
  }
}
