import 'package:flutter/material.dart';

import 'app_dialogs.dart';

class GenericFormDialog extends StatefulWidget {
  const GenericFormDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.fields,
    this.submitLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.onSubmit,
    this.formKey,
    this.isLoading = false,
    this.showHeaderIcon = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final String submitLabel;
  final String cancelLabel;
  final VoidCallback? onSubmit;
  final GlobalKey<FormState>? formKey;
  final bool isLoading;
  final bool showHeaderIcon;

  @override
  State<GenericFormDialog> createState() => _GenericFormDialogState();
}

class _GenericFormDialogState extends State<GenericFormDialog> {
  late final GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
  }

  void _onSave() {
    final state = _formKey.currentState;
    if (state == null) return;
    if (!state.validate()) return;
    state.save();
    widget.onSubmit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialogContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showHeaderIcon) ...[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.fields,
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                      child: Text(widget.cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.isLoading ? null : _onSave,
                      child: widget.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.submitLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
