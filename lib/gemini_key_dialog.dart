import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_key_manager.dart';
import 'widgets/app_dialogs.dart';
import 'services/secrets_service.dart';

/// Shows a dialog that lets the user input & save a Gemini API key.
/// Returns true if a key was saved successfully.
Future<bool?> showGeminiKeyInputDialog(BuildContext context) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  return AppDialogs.show<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final theme = Theme.of(ctx);
            final primary = theme.colorScheme.primary;

            return AppDialogContainer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Form(
                  key: formKey,
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
                                onTap: () => launchUrl(
                                  Uri.parse(
                                    'https://aistudio.google.com/app/apikey',
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: primary, width: 1),
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
                                controller: controller,
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
                              if (error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  error!,
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
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(
                                        ctx,
                                        rootNavigator: true,
                                      ).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setState(() {
                                        saving = true;
                                        error = null;
                                      });
                                      try {
                                        await ApiKeyManager.instance
                                            .saveUserKey(controller.text);
                                            
                                        // Also verify if they have a model selected
                                        final remoteModel = await SecretsService.instance.loadSelectedModel();
                                        if (ctx.mounted) {
                                          Navigator.of(
                                            ctx,
                                            rootNavigator: true,
                                          ).pop(true);
                                          
                                          if (remoteModel == null || remoteModel.isEmpty) {
                                            AppDialogs.showConfirmation(
                                              ctx,
                                              title: 'Key Saved',
                                              message: 'API key saved successfully! Please ensure you select an AI model from your profile settings.',
                                              confirmText: 'Got It',
                                              cancelText: 'Close',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        setState(() {
                                          error = e.toString();
                                          saving = false;
                                        });
                                      }
                                    },
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.key),
                              label: Text(saving ? 'Saving' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      });
}
