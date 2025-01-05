
import 'package:developer_community_app/addpost.dart';
import 'package:developer_community_app/markdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:url_launcher/url_launcher.dart';

class explore extends StatefulWidget {
  const explore({super.key});

  @override
  exploreState createState() => exploreState();
}

class exploreState extends State<explore> {
  // Sample static data
  void openbottmsheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (ctx) => addpost());
  }
  final List<Map<String, dynamic>> questions = [
    {
      'title': 'How to implement state management in Flutter?',
      'description': 'https://unsplash.com/ I am new to Flutter and wondering about the best practices for state management...',
      'tags': ['flutter', 'state-management', 'dart'],
      'votes': 10,
      'answers': 5,
      'code':'''
int main() { 
print("Hello, World!");
  return 0;
}
  ''',
      'timestamp': DateTime.now(),
    },
    {
      'title': 'Understanding async/await in Dart',
      'description': 'Can someone explain how async/await works in Dart with some examples?',
      'tags': ['dart', 'async', 'programming'],
      'votes': 15,
      'answers': 8,
      'timestamp': DateTime.now(),
      'code':''
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Developer Community'),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              // Navigate to profile page
            },
          ),
        ],
      ),

      body: ListView.builder(
        itemCount: questions.length,
        itemBuilder: (context, index) {
          var question = questions[index];
          return QuestionCard(
            title: question['title'],
            description: question['description'],
            tags: List<String>.from(question['tags']),
            votes: question['votes'],
            answers: question['answers'],
            timestamp: question['timestamp'],
            code: question['code'],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
        Get.to(addpost());
        },
        tooltip: 'Ask Question',
        child: Icon(Icons.add),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final String title;
  final String description;
  final String? code;
  final List<String> tags;
  final int votes;
  final int answers;
  final DateTime timestamp;

  const QuestionCard({super.key,
    required this.title,
    required this.code,
    required this.description,
    required this.tags,
    required this.votes,
    required this.answers,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        child: InkWell(
          onTap: () {
            // Navigate to question detail
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: _buildDescription(description, theme),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                if (code != null && code!.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: MarkdownBody(
                            data: "```\n$code\n```",
                            styleSheet: MarkdownStyleSheet(
                              code: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                                backgroundColor: Colors.transparent
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: theme.colorScheme.primaryFixed,
                                borderRadius:BorderRadius.circular(15)

                              ),

                            ),

                          ),
                        ),
                      ],
                    ),
                  ),

                Wrap(
                  spacing: 8,
                  children: tags.map((tag) => Chip(
                    label: Text(tag),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                  )).toList(),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text('$votes', style: theme.textTheme.labelLarge),
                      ],
                    ),
                    Text(
                      'Asked ${_formatDate(timestamp)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      )
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

List<TextSpan> _buildDescription(String description, ThemeData theme) {
  final urlRegex = RegExp(r'(https?://[^\s]+)'); // Matches URLs
  final matches = urlRegex.allMatches(description);

  if (matches.isEmpty) {
    return [TextSpan(text: description)];
  }

  int lastMatchEnd = 0;
  List<TextSpan> spans = [];

  for (final match in matches) {
    // Add text before the URL
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(text: description.substring(lastMatchEnd, match.start)));
    }

    // Add the URL as a clickable link
    final url = description.substring(match.start, match.end);
    spans.add(
      TextSpan(
        text: url,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchURL("https://unsplash.com/"),
      ),
    );

    lastMatchEnd = match.end;
  }

  // Add remaining text after the last URL
  if (lastMatchEnd < description.length) {
    spans.add(TextSpan(text: description.substring(lastMatchEnd)));
  }

  return spans;
}

// Function to launch URLs
void _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('Could not launch $url');
  }
}