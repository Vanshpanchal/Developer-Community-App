import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'ai_service.dart';

class RepoAnalyzerScreen extends StatefulWidget {
  RepoAnalyzerScreen({super.key});

  @override
  State<RepoAnalyzerScreen> createState() => _RepoAnalyzerScreenState();
}

class _RepoAnalyzerScreenState extends State<RepoAnalyzerScreen> {
  final _repoUrlCtrl = TextEditingController();
  final _readmeCtrl = TextEditingController();
  final List<_FileSnippet> _snippets = [];
  bool _loading = false;
  String? _result;
  String? _error;

  void _addSnippet() {
    setState(() {
      _snippets.add(_FileSnippet());
    });
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    final url = _repoUrlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() {
        _error = 'Enter a valid GitHub repository URL.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final files = <String, String>{};
      for (final s in _snippets) {
        final name = s.nameCtrl.text.trim();
        final content = s.contentCtrl.text.trim();
        if (name.isNotEmpty && content.isNotEmpty) files[name] = content;
      }
      final res = await AIService().analyzeRepository(
        repoUrl: url,
        readme:
            _readmeCtrl.text.trim().isEmpty ? null : _readmeCtrl.text.trim(),
        files: files,
      );
      setState(() {
        _result = res;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _repoUrlCtrl.dispose();
    _readmeCtrl.dispose();
    for (final s in _snippets) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Repo Analyzer'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          IconButton(
            tooltip: 'Paste README from clipboard',
            icon: Icon(Icons.paste),
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              if (data?.text != null) {
                _readmeCtrl.text = data!.text!;
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _analyze,
        icon: _loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.auto_fix_high),
        label: Text('Analyze'),
      ),
      body: LayoutBuilder(
        builder: (ctx, c) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repository URL', style: theme.textTheme.labelLarge),
              SizedBox(height: 4),
              TextField(
                controller: _repoUrlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://github.com/owner/repo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              SizedBox(height: 16),
              ExpansionTile(
                title: Text('Optional: Paste README snippet'),
                children: [
                  TextField(
                    controller: _readmeCtrl,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: 'README content (optional, improves accuracy)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('Key File Snippets', style: theme.textTheme.labelLarge),
                  Spacer(),
                  TextButton.icon(
                      onPressed: _addSnippet,
                      icon: Icon(Icons.add),
                      label: Text('Add file'))
                ],
              ),
              ..._snippets.map((s) => _SnippetCard(
                  snippet: s,
                  onRemove: () {
                    setState(() {
                      _snippets.remove(s);
                    });
                  })),
              SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              if (_result != null) ...[
                Divider(height: 32),
                Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 8),
                    Text('Analysis', style: theme.textTheme.titleMedium),
                    Spacer(),
                    IconButton(
                      tooltip: 'Copy Markdown',
                      icon: Icon(Icons.copy_all),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _result!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Analysis copied')));
                        }
                      },
                    ),
                  ],
                ),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: MarkdownBody(
                      data: _result!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        h2: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.primary),
                        p: theme.textTheme.bodyMedium,
                        listBullet: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileSnippet {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController contentCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    contentCtrl.dispose();
  }
}

class _SnippetCard extends StatelessWidget {
  final _FileSnippet snippet;
  final VoidCallback onRemove;
  _SnippetCard({required this.snippet, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: snippet.nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'filename (e.g. lib/main.dart)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.insert_drive_file_outlined),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove',
                  icon: Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
            SizedBox(height: 8),
            TextField(
              controller: snippet.contentCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Relevant excerpt (truncate large files)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
