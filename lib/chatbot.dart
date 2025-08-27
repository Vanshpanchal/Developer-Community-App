import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

const apiKey = 'AIza------tMww4--------------'; // Your Gemini API key

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Chatbot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String _response = '';

  @override
  void initState() {
    super.initState();
    // Initialize Gemini with the API key inside the chat screen
    Gemini.init(apiKey: apiKey, enableDebugging: true);
  }

  void _generateResponse(String prompt) async {
    try {
      // Generate response from Gemini API based on user input
      final result = await Gemini.instance.prompt(parts: [
        Part.text(prompt),
      ]);

      setState(() {
        _response = result?.output ?? 'Error: No response received';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gemini Chatbot')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Ask something'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                String userInput = _controller.text.trim();
                if (userInput.isNotEmpty) {
                  _generateResponse(userInput);
                }
              },
              child: Text('Get Response'),
            ),
            SizedBox(height: 16),
            Text(
              _response,
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
