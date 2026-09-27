import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'messagemodel.dart';
import 'ai_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_snackbar.dart';

class CopyOverlay extends StatefulWidget {
  final BuildContext? context;

  const CopyOverlay({super.key, this.context});

  @override
  State<CopyOverlay> createState() => _CopyOverlayState();
}

class _CopyOverlayState extends State<CopyOverlay>
    with SingleTickerProviderStateMixin {
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
    _controller.forward().then((_) {
      if (mounted) {
        return _controller.reverse();
      }
    }).then((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
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
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Copied to clipboard',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen1 extends StatefulWidget {
  const ChatScreen1({super.key});

  @override
  State<ChatScreen1> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen1> {
  final TextEditingController _controller = TextEditingController();
  late Box<Message> _messageBox;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageBox = Hive.box<Message>('chat_messages');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> getGeminiResponse(String prompt) async {
    return AIService().generateText(prompt);
  }

  void _showCopiedSnackBar() {
    AppSnackbar.success('Message copied to clipboard');
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = Message(text: _controller.text, isUser: true);
    await _messageBox.add(userMessage);
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isTyping = true;
      });
    }
    _controller.clear();
    _scrollToBottom();

    final botResponse = await getGeminiResponse(userMessage.text);
    final botMessage = Message(text: botResponse, isUser: false);
    await _messageBox.add(botMessage);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
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
                    Color(0xFF1A1A1A),
                    Color(0xFF2D2D2D),
                  ]
                : [
                    Color(0xFFF8F9FA),
                    Color(0xFFE9ECEF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(Icons.smart_toy, color: Colors.white),
                    ),
                    SizedBox(width: 12),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _messageBox.listenable(),
                  builder: (context, Box<Message> box, _) {
                    final messages = box.values.toList();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollBottom();
                    });
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final showTimestamp = index == 0 ||
                            messages[index]
                                    .timestamp
                                    .difference(messages[index - 1].timestamp)
                                    .inMinutes >
                                5;
                        return Column(
                          children: [
                            if (showTimestamp)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  DateFormat('MMM d, h:mm a')
                                      .format(message.timestamp),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                    );
                  },
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      SizedBox(width: 16),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Thinking...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxHeight: 120,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          scrollPhysics: const BouncingScrollPhysics(),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Container(
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
                                size: 20,
                              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment:
              message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender Info Row
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isUser) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.smart_toy_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Assistant',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'You',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.person,
                        size: 10,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Message Body
            GestureDetector(
              onLongPress: !message.isUser ? () => _copyToClipboard(context) : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? AppTheme.primaryColor
                      : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: message.isUser ? const Radius.circular(2) : null,
                    bottomLeft: !message.isUser ? const Radius.circular(2) : null,
                  ),
                  border: !message.isUser
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: MarkdownBody(
                  data: message.text,
                  styleSheet: message.isUser
                      ? MarkdownStyleSheet(
                          p: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        )
                      : MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: isDark ? Colors.grey.shade200 : Colors.black87,
                          ),
                          code: theme.textTheme.bodySmall?.copyWith(
                            backgroundColor: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : Colors.grey.shade100,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
