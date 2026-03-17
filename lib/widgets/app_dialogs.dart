import 'package:flutter/material.dart';

enum AppDialogType { info, success, error }

class AppDialogs {
  AppDialogs._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      useRootNavigator: useRootNavigator,
      pageBuilder: (context, _, __) => SafeArea(
        child: Builder(builder: builder),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.97,
              end: 1.0,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String actionText = 'OK',
    VoidCallback? onDismiss,
  }) async {
    await show<void>(
      context: context,
      builder: (ctx) => _MessageDialog(
        type: AppDialogType.info,
        title: title,
        message: message,
        actionText: actionText,
        onAction: () {
          Navigator.of(ctx, rootNavigator: true).maybePop();
          onDismiss?.call();
        },
      ),
    );
  }

  static Future<void> showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String actionText = 'OK',
    VoidCallback? onDismiss,
  }) async {
    await show<void>(
      context: context,
      builder: (ctx) => _MessageDialog(
        type: AppDialogType.success,
        title: title,
        message: message,
        actionText: actionText,
        onAction: () {
          Navigator.of(ctx, rootNavigator: true).maybePop();
          onDismiss?.call();
        },
      ),
    );
  }

  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String actionText = 'OK',
    VoidCallback? onDismiss,
  }) async {
    await show<void>(
      context: context,
      builder: (ctx) => _MessageDialog(
        type: AppDialogType.error,
        title: title,
        message: message,
        actionText: actionText,
        onAction: () {
          Navigator.of(ctx, rootNavigator: true).maybePop();
          onDismiss?.call();
        },
      ),
    );
  }

  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'Cancel',
    bool barrierDismissible = true,
  }) {
    return show<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => _ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }
}

class AppDialogContainer extends StatelessWidget {
  const AppDialogContainer({
    super.key,
    required this.child,
    this.maxWidth = 420,
    this.maxHeightFactor = 0.8,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context).size;

    return Center(
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: media.height * maxHeightFactor,
          ),
          child: Material(
            color: theme.dialogTheme.backgroundColor ?? theme.cardColor,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            borderRadius: (theme.dialogTheme.shape is RoundedRectangleBorder)
                ? (theme.dialogTheme.shape as RoundedRectangleBorder)
                    .borderRadius as BorderRadius
                : BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: (theme.dialogTheme.shape is RoundedRectangleBorder)
                  ? (theme.dialogTheme.shape as RoundedRectangleBorder)
                      .borderRadius as BorderRadius
                  : BorderRadius.circular(20),
              child: ScrollConfiguration(
                behavior: const _NoGlowScrollBehavior(),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({
    required this.type,
    required this.title,
    required this.message,
    required this.actionText,
    required this.onAction,
  });

  final AppDialogType type;
  final String title;
  final String message;
  final String actionText;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (icon, accent) = switch (type) {
      AppDialogType.info => (Icons.info_outline_rounded, cs.primary),
      AppDialogType.success => (
          Icons.check_circle_outline_rounded,
          Colors.green
        ),
      AppDialogType.error => (Icons.error_outline_rounded, cs.error),
    };

    return AppDialogContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialogContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(false),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(true),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
