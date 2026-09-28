import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_logger.dart';
import 'app_snackbar.dart';

/// Posting requires a verified email address (audit SEC-15).
///
/// Returns true when the signed-in user's email is verified. Otherwise shows
/// a dialog that can resend the verification email and re-check, and returns
/// whether the user is verified when it closes.
Future<bool> ensureEmailVerified(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  if (user.emailVerified) return true;

  try {
    await user.reload();
  } catch (e) {
    AppLogger.warning('Could not refresh verification state: $e');
  }
  if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) return true;
  if (!context.mounted) return false;

  final verified = await showDialog<bool>(
    context: context,
    builder: (_) => const _VerifyEmailDialog(),
  );
  return verified ?? false;
}

class _VerifyEmailDialog extends StatefulWidget {
  const _VerifyEmailDialog();

  @override
  State<_VerifyEmailDialog> createState() => _VerifyEmailDialogState();
}

class _VerifyEmailDialogState extends State<_VerifyEmailDialog> {
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      AppSnackbar.success('Verification email sent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      AppSnackbar.error(e.code == 'too-many-requests'
          ? 'Please wait a few minutes before requesting another email.'
          : 'Could not send the email. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
      Navigator.of(context).pop(true);
    } else {
      AppSnackbar.info("Your email isn't verified yet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return AlertDialog(
      title: const Text('Verify your email'),
      content: Text(
        'To keep DevSphere free of spam, please verify $email before posting. '
        'Open the link we sent you, then tap "I\'ve verified".',
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Resend email'),
        ),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: const Text("I've verified"),
        ),
      ],
    );
  }
}
