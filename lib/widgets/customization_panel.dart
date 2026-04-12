import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/avatar_provider.dart';
import '../services/avatar_service.dart';
import 'option_selector.dart';

/// Full customization panel: style picker, hair, eyes, mouth, background.
/// Sections are only shown when the selected style supports them.
class CustomizationPanel extends StatelessWidget {
  const CustomizationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AvatarProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _StyleSection(provider: provider),
            const SizedBox(height: 16),
            _BackgroundSection(provider: provider),
            const SizedBox(height: 16),
            if (provider.supportsCustomization('hair')) ...[
              _CustomSection(
                title: 'Hair Style',
                icon: Icons.face,
                options: provider.optionsFor('hair'),
                selected: provider.config.hair,
                onSelected: (val) => provider.updateHair(val),
              ),
              const SizedBox(height: 16),
            ],
            if (provider.supportsCustomization('eyes')) ...[
              _CustomSection(
                title: 'Eyes',
                icon: Icons.remove_red_eye_outlined,
                options: provider.optionsFor('eyes'),
                selected: provider.config.eyes,
                onSelected: (val) => provider.updateEyes(val),
              ),
              const SizedBox(height: 16),
            ],
            if (provider.supportsCustomization('mouth')) ...[
              _CustomSection(
                title: 'Mouth',
                icon: Icons.sentiment_satisfied_alt_outlined,
                options: provider.optionsFor('mouth'),
                selected: provider.config.mouth,
                onSelected: (val) => provider.updateMouth(val),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Style selector — custom expandable tile (replaces DropdownButtonFormField)
// ---------------------------------------------------------------------------

class _StyleSection extends StatefulWidget {
  final AvatarProvider provider;
  const _StyleSection({required this.provider});

  @override
  State<_StyleSection> createState() => _StyleSectionState();
}

class _StyleSectionState extends State<_StyleSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _rotateAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStyle = AvatarService.supportedStyles.firstWhere(
      (s) => s['id'] == widget.provider.config.style,
      orElse: () => AvatarService.supportedStyles.first,
    );

    return _SectionCard(
      title: 'Avatar Style',
      icon: Icons.auto_awesome,
      child: Column(
        children: [
          // Trigger row — shows the currently selected style
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _expanded
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: _expanded ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(currentStyle['emoji']!,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentStyle['label']!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotateAnim,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanding list of style options
          SizeTransition(
            sizeFactor: _fadeAnim,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: AvatarService.supportedStyles.map((style) {
                    final isSelected =
                        style['id'] == widget.provider.config.style;
                    return _StyleOptionTile(
                      style: style,
                      isSelected: isSelected,
                      isLast: style == AvatarService.supportedStyles.last,
                      onTap: () {
                        widget.provider.changeStyle(style['id']!);
                        _toggle();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleOptionTile extends StatelessWidget {
  final Map<String, String> style;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _StyleOptionTile({
    required this.style,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
        ),
        child: Row(
          children: [
            Text(style['emoji']!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                style['label']!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background colour picker section
// ---------------------------------------------------------------------------

class _BackgroundSection extends StatelessWidget {
  final AvatarProvider provider;
  const _BackgroundSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = AvatarService.backgroundColors;
    final selected = provider.config.backgroundColor;

    return _SectionCard(
      title: 'Background Color',
      icon: Icons.palette_outlined,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final hex = colors[i]['hex']!;
            final label = colors[i]['label']!;
            final isSelected = selected == hex;
            final color = _hexToColor(hex);

            return GestureDetector(
              onTap: () => provider.updateBackground(hex),
              child: Tooltip(
                message: label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          )
                        : Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.black54, size: 18)
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return Colors.grey.shade200;
    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey.shade200;
    }
  }
}

// ---------------------------------------------------------------------------
// Generic option section (hair, eyes, mouth)
// ---------------------------------------------------------------------------

class _CustomSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CustomSection({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: OptionSelector(
        options: options,
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section card wrapper
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
