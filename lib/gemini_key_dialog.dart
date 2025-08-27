import 'package:flutter/material.dart';
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Gemini API Key'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter your Google AI Studio (Gemini) API key. It is stored only on this device; a hash is synced for presence.'),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: controller,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'eg. AIza...'
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!RegExp(r'^[A-Za-z0-9_\-]{20,}$').hasMatch(v.trim())) return 'Looks invalid';
                      return null;
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                onPressed: saving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setState(() { saving = true; error = null; });
                  try {
                    await ApiKeyManager.instance.saveUserKey(controller.text);
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  } catch (e) {
                    setState(() { error = e.toString(); saving = false; });
                  }
                },
                icon: saving ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.key),
                label: Text(saving ? 'Saving' : 'Save'),
              )
            ],
          );
        },
      );
    }
  );
}
