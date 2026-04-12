import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/avatar_provider.dart';
import '../services/avatar_service.dart';
import '../widgets/avatar_grid.dart';
import '../widgets/avatar_preview.dart';
import '../widgets/customization_panel.dart';
import '../utils/app_snackbar.dart';

/// Main avatar selection and customisation screen.
/// Uses a TabBar to switch between Predefined grid and Customise panel.
class AvatarScreen extends StatefulWidget {
  /// Optional callback invoked when the user taps Save, passing the JSON string.
  final ValueChanged<String>? onSaved;

  const AvatarScreen({super.key, this.onSaved});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _saveAvatar(AvatarProvider provider) async {
    setState(() => _isSaving = true);
    try {
      // Saves locally + updates profilePicture in Firebase
      final url = await provider.saveAvatar();
      // Notify parent (e.g. AvatarManager bottom sheet) with the URL
      widget.onSaved?.call(url);
      if (mounted) AppSnackbar.success('Avatar saved! ✨');
    } catch (e) {
      if (mounted) AppSnackbar.error('Failed to save avatar');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AvatarProvider(),
      child: _AvatarScreenBody(
        tabController: _tabController,
        isSaving: _isSaving,
        onSave: _saveAvatar,
      ),
    );
  }
}

class _AvatarScreenBody extends StatelessWidget {
  final TabController tabController;
  final bool isSaving;
  final Future<void> Function(AvatarProvider) onSave;

  const _AvatarScreenBody({
    required this.tabController,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AvatarProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, provider),
          SliverFillRemaining(
            child: Column(
              children: [
                _buildTabBar(context),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: const [
                      AvatarGrid(),
                      CustomizationPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SliverAppBar with avatar preview and action buttons
  // ---------------------------------------------------------------------------

  Widget _buildSliverAppBar(BuildContext context, AvatarProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Avatar Studio',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      actions: [
        // Reset
        IconButton(
          tooltip: 'Reset to default',
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: provider.resetAvatar,
          color: colorScheme.onSurface,
        ),
        // Shuffle
        IconButton(
          tooltip: 'Randomize avatar',
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: provider.randomizeAvatar,
          color: colorScheme.primary,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.blurBackground],
        background: _buildHeroSection(context, provider),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AvatarProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.6),
            colorScheme.surface,
          ],
        ),
      ),
      // LayoutBuilder lets us size the avatar proportionally to actual height
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availH = constraints.maxHeight;
          // Reserve space: appBar(56) + seed text(~18) + badge(~26) + buttons(~44) + gaps
          final reservedH = 56 + 18 + 26 + 44 + 12 + 8 + 12 + 8;
          // Avatar gets the remaining space, clamped between 72–130 px
          final avatarSize =
              (availH - reservedH).clamp(72.0, 130.0);
          // Scale gaps proportionally
          final gap = ((availH - reservedH - avatarSize) / 6).clamp(4.0, 12.0);

          return SingleChildScrollView(
            // physics: NeverScrollableScrollPhysics keeps it static inside
            // FlexibleSpaceBar yet prevents overflow on tiny screens
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availH),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 56 + gap), // app bar + top breathing room
                  // Live Avatar Preview — size adapts to available height
                  AvatarPreview(size: avatarSize),
                  SizedBox(height: gap),
                  // Seed label
                  Text(
                    'Seed: ${provider.config.seed}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: gap * 0.5),
                  // Style badge
                  _StyleBadge(style: provider.config.style),
                  SizedBox(height: gap),
                  // Action row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: Icons.shuffle_rounded,
                        label: 'Shuffle',
                        onTap: provider.randomizeAvatar,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
                        icon: Icons.save_rounded,
                        label: 'Save',
                        onTap: () => onSave(provider),
                        color: colorScheme.primary,
                        filled: true,
                      ),
                    ],
                  ),
                  SizedBox(height: gap),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view_rounded, size: 16),
                SizedBox(width: 6),
                Text('Predefined', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16),
                SizedBox(width: 6),
                Text('Customize', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _StyleBadge extends StatelessWidget {
  final String style;
  const _StyleBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final styleInfo = AvatarService.supportedStyles.firstWhere(
      (s) => s['id'] == style,
      orElse: () => {'id': style, 'label': style, 'emoji': '🎨'},
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${styleInfo['emoji']} ${styleInfo['label']}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
