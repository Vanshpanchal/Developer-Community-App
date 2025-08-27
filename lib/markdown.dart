import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class markdown extends StatefulWidget {
   markdown({super.key});

  @override
  State<markdown> createState() => _markdownState();
}

class _markdownState extends State<markdown> {
  final TextEditingController _controller = TextEditingController();
  bool isPreviewMode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text('Markdown Editor'),
      ),
      body: Row(
        children: [
          // Editor Section
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              decoration:  InputDecoration(
                hintText: 'Enter your markdown here...',
                contentPadding: EdgeInsets.all(16),
              ),
              onChanged: (text) {
                setState(() {});
              },
            ),
          ),
          // Vertical Divider
           VerticalDivider(thickness: 1, width: 1),
          // Preview Section
          Expanded(
            child: Markdown(data: _controller.text),
          ),
        ],
      ),
    );
  }
}
