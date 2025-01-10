import 'package:flutter/material.dart';

import 'gemini_api.dart';
// import '../services/chat_gpt_service.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  late ChatGPTService _chatGPTService;
  String _role = "assistant";

  @override
  void initState() {
    super.initState();
    _chatGPTService = ChatGPTService(apiKey: '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');
  }

  Future<void> _sendMessage() async {
    final userMessage = _messageController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': userMessage});
    });
    _messageController.clear();

    try {
      final botMessage = await _chatGPTService.generateResponse(userMessage, _role);
      setState(() {
        _messages.add({'sender': 'bot', 'text': botMessage});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Failed to fetch response: $e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ChatGPT Chatbot'),
        actions: [
          DropdownButton<String>(
            value: _role,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _role = value;
                });
              }
            },
            items: [
              DropdownMenuItem(value: "assistant", child: Text("Assistant")),
              DropdownMenuItem(value: "expert", child: Text("Expert")),
              DropdownMenuItem(value: "friend", child: Text("Friend")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message['text']!,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
