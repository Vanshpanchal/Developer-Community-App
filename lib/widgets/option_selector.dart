import 'package:flutter/material.dart';

/// Horizontal scrolling chip selector for string-based option lists.
/// Shows a "None" chip to allow clearing the selection,
/// plus one chip per option with text perfectly centered horizontally + vertically.
class OptionSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool showNoneOption;

  const OptionSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.showNoneOption = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surfaceContainerHighest;

    final allOptions = showNoneOption
        ? <String?>[null, ...options]
        : options.cast<String?>();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = allOptions[index];
          final isSelected = option == selected;
          final label = option == null ? 'None' : _prettify(option);

          return GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              // Fixed height so every chip is the same size
              height: 40,
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? primary : surface,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: primary, width: 1.5)
                    : Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              // Center the text both vertically and horizontally inside the chip
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    height: 1.0, // prevent extra line-height from pushing text off-center
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Converts camelCase / snake_case / hyphen-case to a human-readable label.
  String _prettify(String raw) {
    // Insert a space before uppercase letters (camelCase → camel Case)
    final spaced = raw.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
    // Replace underscores and hyphens with spaces
    final cleaned = spaced.replaceAll(RegExp(r'[_\-]'), ' ');
    // Capitalise the first letter of every word
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
