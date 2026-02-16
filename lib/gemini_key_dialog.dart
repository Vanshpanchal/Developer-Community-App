import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_key_manager.dart';

/// Shows a dialog that lets the user input & save a Gemini API key.
/// Returns true if a key was saved successfully.
Future<bool?> showGeminiKeyInputDialog(BuildContext context) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  return showDialog<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Gemini API Key'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Enter your Google AI Studio (Gemini) API key. It is stored only on this device; a hash is synced for presence.'),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => launchUrl(
                          Uri.parse('https://aistudio.google.com/app/apikey')),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.open_in_new,
                                color: Colors.blue, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Get API Key from Google AI Studio',
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500),
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
                      decoration: InputDecoration(
                          labelText: 'API Key', hintText: 'eg. AIza...'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!RegExp(r'^[A-Za-z0-9_\-]{20,}$')
                            .hasMatch(v.trim())) return 'Looks invalid';
                        return null;
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await ApiKeyManager.instance
                                .saveUserKey(controller.text);
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
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
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.key),
                  label: Text(saving ? 'Saving' : 'Save'),
                )
              ],
            );
          },
        );
      });
}
