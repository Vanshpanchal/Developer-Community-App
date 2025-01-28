import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CopyOverlay extends StatefulWidget {
  final BuildContext context;

  const CopyOverlay({super.key, required this.context});

  @override
  State<CopyOverlay> createState() => _CopyOverlayState();
}

class _CopyOverlayState extends State<CopyOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );
    _controller.forward().then((_) => _controller.reverse()).then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: AlertDialog(
        backgroundColor: Colors.black87,
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Copied to clipboard',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser})
      : timestamp = DateTime.now();
}

class ChatScreen1 extends StatefulWidget {
  const ChatScreen1({super.key});

  @override
  State<ChatScreen1> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen1> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isTyping = false;

  static const String apiKey = 'AIzaSyAprvvV7xT49a4RSzRSr7RQWAZbMI9s7UM';
  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  Future<String> getGeminiResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  void _showCopiedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add(Message(text: userMessage, isUser: true));
      _isLoading = true;
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    final botResponse = await getGeminiResponse(userMessage);
    setState(() {
      _messages.add(Message(text: botResponse, isUser: false));
      _isLoading = false;
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              const Color(0xFF1A1A1A),
              const Color(0xFF2D2D2D),
            ]
                : [
              const Color(0xFFF8F9FA),
              const Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.smart_toy, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini Assistant',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_isTyping)
                          Text(
                            'typing...',
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final showTimestamp = index == 0 ||
                        _messages[index].timestamp.difference(_messages[index - 1].timestamp).inMinutes > 5;

                    return Column(
                      children: [
                        if (showTimestamp)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('MMM d, h:mm a').format(message.timestamp),
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        MessageBubble(
                          message: message,
                          onCopy: _showCopiedSnackBar,
                        ),
                      ],
                    );
                  },
                ),
              ),

              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Thinking...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _sendMessage,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback onCopy;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onCopy,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    HapticFeedback.lightImpact();
    onCopy();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: !message.isUser ? () => _copyToClipboard(context) : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: message.isUser ? null : const Radius.circular(0),
                    bottomRight: message.isUser ? const Radius.circular(0) : null,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: message.isUser
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
