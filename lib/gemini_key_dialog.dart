import 'package:flutter/material.dart';
import 'api_key_manager.dart';
import 'widgets/app_dialogs.dart';
import 'services/secrets_service.dart';
import 'utils/url_helper.dart';

/// Shows a dialog that lets the user input & save a Gemini API key.
/// Returns true if a key was saved successfully.
Future<bool?> showGeminiKeyInputDialog(BuildContext context) {
  return AppDialogs.show<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _GeminiKeyDialog(),
  );
}

class _GeminiKeyDialog extends StatefulWidget {
  const _GeminiKeyDialog();

  @override
  State<_GeminiKeyDialog> createState() => _GeminiKeyDialogState();
}

class _GeminiKeyDialogState extends State<_GeminiKeyDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AppDialogContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Gemini API Key',
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your Google AI Studio (Gemini) API key. It is stored only on this device; a hash is synced for presence.',
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => openExternalUrl(
                            'https://aistudio.google.com/app/apikey'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primary, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.open_in_new,
                                color: primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Get API Key from Google AI Studio',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _controller,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'eg. AIza...',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (!RegExp(r'^[A-Za-z0-9_\-]{20,}$')
                              .hasMatch(v.trim())) {
                            return 'Looks invalid';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              setState(() {
                                _saving = true;
                                _error = null;
                              });
                              try {
                                await ApiKeyManager.instance
                                    .saveUserKey(_controller.text);

                                // Also verify if they have a model selected
                                final remoteModel = await SecretsService
                                    .instance
                                    .loadSelectedModel();
                                if (context.mounted) {
                                  final navigator = Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  );
                                  // Use a context that outlives this dialog
                                  // for the follow-up prompt.
                                  final hostContext = navigator.context;
                                  navigator.pop(true);

                                  if (remoteModel == null ||
                                      remoteModel.isEmpty) {
                                    AppDialogs.showConfirmation(
                                      hostContext,
                                      title: 'Key Saved',
                                      message:
                                          'API key saved successfully! Please ensure you select an AI model from your profile settings.',
                                      confirmText: 'Got It',
                                      cancelText: 'Close',
                                    );
                                  }
                                }
                              } catch (e) {
                                if (!mounted) return;
                                setState(() {
                                  _error =
                                      'Could not save the key. Please try again.';
                                  _saving = false;
                                });
                              }
                            },
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.key),
                      label: Text(_saving ? 'Saving' : 'Save'),
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
