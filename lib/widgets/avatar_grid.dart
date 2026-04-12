import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/avatar_config.dart';
import '../providers/avatar_provider.dart';
import '../services/avatar_service.dart';
import 'shimmer_skeleton.dart';

/// Responsive predefined avatar grid with Male / Female / All filter tabs.
class AvatarGrid extends StatelessWidget {
  const AvatarGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // _GenderFilterBar(),
        Expanded(child: _AvatarGridBody()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gender filter chip bar
// ---------------------------------------------------------------------------

class _GenderFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AvatarProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _GenderChip(
            label: '👤 All',
            value: AvatarGender.all,
            selected: provider.gender,
            onTap: () => provider.setGender(AvatarGender.all),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _GenderChip(
            label: '♂ Male',
            value: AvatarGender.male,
            selected: provider.gender,
            onTap: () => provider.setGender(AvatarGender.male),
            theme: theme,
          ),
          const SizedBox(width: 8),
          _GenderChip(
            label: '♀ Female',
            value: AvatarGender.female,
            selected: provider.gender,
            onTap: () => provider.setGender(AvatarGender.female),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final AvatarGender value;
  final AvatarGender selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _GenderChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final primary = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar grid body — uses filteredConfigs from provider
// ---------------------------------------------------------------------------

class _AvatarGridBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AvatarProvider>();
    final configs = provider.filteredConfigs;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final crossAxisCount = screenWidth < 360
        ? 3
        : screenWidth < 600
            ? 4
            : 5;

    if (configs.isEmpty) {
      return Center(
        child: Text(
          'No avatars found',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final avatarConfig = configs[index];
        final isSelected = provider.config.seed == avatarConfig.seed &&
            provider.config.style == avatarConfig.style;

        return _AvatarGridItem(
          config: avatarConfig,
          isSelected: isSelected,
          onTap: () => provider.selectPredefined(avatarConfig),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual animated grid tile
// ---------------------------------------------------------------------------

class _AvatarGridItem extends StatefulWidget {
  final AvatarConfig config;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarGridItem({
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AvatarGridItem> createState() => _AvatarGridItemState();
}

class _AvatarGridItemState extends State<_AvatarGridItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) {
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _controller,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: widget.isSelected
                ? Border.all(color: color, width: 3)
                : Border.all(color: Colors.transparent, width: 3),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                : null,
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.config.avatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => ShimmerSkeleton.circular(
                width: double.infinity,
                height: double.infinity,
              ),
              errorWidget: (_, __, ___) => Container(
                color: theme.colorScheme.errorContainer,
                child: Icon(Icons.person, color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
