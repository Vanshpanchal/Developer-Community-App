import 'package:flutter/material.dart';
import '../screens/avatar_screen.dart';

/// Backward-compatible entry point for avatar picking.
/// Firebase update is handled inside [AvatarProvider.saveAvatar] → [SecretsService].
class AvatarManager {
  /// Kept for code that still reads URLs directly (e.g. default fallbacks).
  static const List<String> avatars = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=Felix&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Aneka&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Caleb&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Willow&backgroundColor=d1d4f9',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Leo&backgroundColor=ffd5dc',
  ];

  /// Opens the full [AvatarScreen] in a modal bottom sheet.
  /// [onSelected] receives the chosen avatar URL after the user taps Save.
  /// Firebase profilePicture is already updated before this callback fires.
  static Future<void> showAvatarPicker(
    BuildContext context,
    Function(String) onSelected,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, _) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: AvatarScreen(
            onSaved: (url) {
              // Firebase already updated inside AvatarProvider.saveAvatar()
              Navigator.of(ctx).pop();
              onSelected(url);
            },
          ),
        ),
      ),
    );
  }
}
