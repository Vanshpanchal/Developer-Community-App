import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'gemini_key_dialog.dart';

class DeveloperPortfolioPage extends StatefulWidget {
  // const DeveloperPortfolioPage({super.key, this.userId});
  final String? userId; // if null -> current authenticated user
  const DeveloperPortfolioPage({super.key, this.userId});

  @override
  State<DeveloperPortfolioPage> createState() => _DeveloperPortfolioPageState();
}

class _DeveloperPortfolioPageState extends State<DeveloperPortfolioPage> {
  final _auth = FirebaseAuth.instance;
  bool _loading = true;
  bool _aiLoading = false;
  String? _aiSummary;
  String? _error;
  bool _editing = false;
  final _editController = TextEditingController();
  Map<String,dynamic>? _githubStats;
  List<Map<String,dynamic>> _history = [];
  String? _profilePicUrl;
  String? _username;
  bool _summaryExpanded = false;
  bool _overviewExpanded = true;
  bool _tagsExpanded = true;
  bool _githubExpanded = true;
  bool _historyExpanded = false;
  String? _githubUsername;
  String? _userBio;
  DateTime? _userCreated;
  String? _profileEmail; // email of viewed profile (may differ from signed-in user)

  bool get _isSelf {
    final cu = _auth.currentUser;
    if (cu == null) return false;
    return widget.userId == null || widget.userId == cu.uid;
  }

  List<Map<String,dynamic>> _discussions = [];
  List<Map<String,dynamic>> _explorePosts = [];
  List<Map<String,dynamic>> _replies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  _loadHistory();
  }

  Future<void> _loadData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() { _error = 'Not authenticated'; _loading = false; });
      return;
    }
    final targetUid = widget.userId ?? currentUser.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('User').doc(targetUid).get();
      final data = userDoc.data() ?? {};
      _profilePicUrl = data['profilePicture'] as String?;
      _username = data['Username'] as String? ?? data['username'] as String? ?? 'Developer';
      _profileEmail = data['Email'] as String? ?? (_isSelf ? currentUser.email : null);
      _userBio = data['bio'] as String?;
      final createdRaw = data['createdAt'];
      if (createdRaw is Timestamp) {
        _userCreated = createdRaw.toDate();
      } else if (createdRaw is String) {
        _userCreated = DateTime.tryParse(createdRaw);
      }

      final discSnap = await FirebaseFirestore.instance
          .collection('Discussions')
          .where('Uid', isEqualTo: targetUid)
          .get();
      final exploreSnap = await FirebaseFirestore.instance
          .collection('Explore')
          .where('Uid', isEqualTo: targetUid)
          .get();

      _discussions = discSnap.docs.map((e) => e.data()).toList();
      _explorePosts = exploreSnap.docs.map((e) => e.data()).toList();

      // Replies authored by target user across discussions (limit to avoid huge reads)
      final allDisc = await FirebaseFirestore.instance.collection('Discussions').limit(60).get();
      _replies.clear();
      final replyFutures = <Future>[];
      for (final d in allDisc.docs) {
        replyFutures.add(FirebaseFirestore.instance
            .collection('Discussions')
            .doc(d.id)
            .collection('Replies')
            .where('uid', isEqualTo: targetUid)
            .get().then((qs) {
          for (final r in qs.docs) {
            _replies.add(r.data());
          }
        }));
      }
      await Future.wait(replyFutures);

      await _maybeFetchGithub(overrideUid: targetUid);
    } catch (e) {
      _error = 'Load failed: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _generateAISummary() async {
    if (_aiLoading) return; // guard
    setState(() { _aiLoading = true; _aiSummary = null; });
    try {
      final user = _auth.currentUser;
      final stats = _buildStats();
      await _maybeFetchGithub();
      final mergedStats = {...stats, if (_githubStats != null) 'github': _githubStats};
      final summary = await AIService().generatePortfolioSummary(
        stats: mergedStats,
        github: _githubStats,
        userHandle: user?.email,
      );
      if (summary == AIService.missingKeyMessage) {
        if (mounted) _showMissingKeyDialog();
      } else if (mounted) {
        setState(() { _aiSummary = summary; _editController.text = summary; });
        _storeHistory(summary);
      }
    } catch (e) {
      if (mounted) setState(() { _aiSummary = 'AI summary failed: $e'; });
    } finally {
      if (mounted) setState(() { _aiLoading = false; });
    }
  }

  void _showMissingKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key Needed'),
        content: const Text('To generate an AI portfolio summary, please add your Gemini API key in settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Future.microtask(() async {
                final saved = await showGeminiKeyInputDialog(context);
                if (saved == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemini key saved. Retry AI summary.')));
                }
              });
            },
            child: const Text('Add Key'),
          ),
        ],
      ),
    );
  }

  String _portfolioPrompt(String userId, Map<String,dynamic> stats) {
    return 'Generate a concise markdown portfolio summary. Include sections: Profile Highlights, Tech Focus, Community Impact (discussions ${stats['discussionCount']} / answers ${stats['replyCount']}), Suggested Growth Areas, Notable Topics (list tag frequency), Contribution Level Estimate (1 line). Stats JSON: ${stats.toString()}';
  }

  Map<String,dynamic> _buildStats() {
    final tagFreq = <String,int>{};
    for (final d in _discussions) {
      final tags = (d['Tags'] as List?)?.cast<dynamic>() ?? [];
      for (final t in tags) {
        if (t is String) tagFreq[t] = (tagFreq[t] ?? 0) + 1;
      }
    }
    for (final e in _explorePosts) {
      final tags = (e['Tags'] as List?)?.cast<dynamic>() ?? [];
      for (final t in tags) { if (t is String) tagFreq[t] = (tagFreq[t] ?? 0) + 1; }
    }
    return {
      'discussionCount': _discussions.length,
      'explorePostCount': _explorePosts.length,
      'replyCount': _replies.length,
      'tags': tagFreq,
    };
  }

  Future<void> _maybeFetchGithub({String? overrideUid}) async {
    if (_githubStats != null) return;
    final uid = overrideUid ?? _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final profileDoc = await FirebaseFirestore.instance.collection('User').doc(uid).get();
      final gh = profileDoc.data()?['github'] as String?;
      _githubUsername = gh;
      if (gh == null || gh.isEmpty) return;
      final headers = {'User-Agent': 'DevCommunityApp'};
      final userResp = await http.get(Uri.parse('https://api.github.com/users/$gh'), headers: headers);
      if (userResp.statusCode != 200) return;
      final data = jsonDecode(userResp.body) as Map<String, dynamic>;
      _githubStats = {
        'public_repos': data['public_repos'],
        'followers': data['followers'],
        'following': data['following'],
        'created_at': data['created_at'],
      };
      final reposResp = await http.get(Uri.parse('https://api.github.com/users/$gh/repos?per_page=50&sort=updated'), headers: headers);
      if (reposResp.statusCode == 200) {
        final repos = jsonDecode(reposResp.body) as List<dynamic>;
        final langCounts = <String,int>{};
        for (final r in repos) {
          final lang = r['language'];
          if (lang is String && lang.isNotEmpty) {
            langCounts[lang] = (langCounts[lang] ?? 0) + 1;
          }
        }
        if (langCounts.isNotEmpty) {
          final sorted = langCounts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
            _githubStats!['languages'] = langCounts;
            _githubStats!['primary_language'] = sorted.first.key;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _storeHistory(String summary) async {
    final user = _auth.currentUser; if (user == null) return;
    final entry = {
      'summary': summary,
      'ts': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance.collection('User').doc(user.uid)
        .collection('PortfolioHistory').add(entry);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = _auth.currentUser; if (user == null) return;
    final qs = await FirebaseFirestore.instance.collection('User').doc(user.uid)
        .collection('PortfolioHistory').orderBy('ts', descending: true).limit(10).get();
    setState(() { _history = qs.docs.map((d)=>{'id': d.id, ...d.data()}).toList(); });
  }

  List<Widget> _buildBadges(Map<String,dynamic> stats) {
    final badges = <Widget>[];
    if (stats['discussionCount'] > 5) badges.add(_badge('Active Discussant'));
    if (stats['replyCount'] > 10) badges.add(_badge('Helper'));
    final tags = stats['tags'] as Map<String,int>;
    if (tags.values.any((c)=>c>=5)) badges.add(_badge('Tag Specialist'));
    if (_githubStats != null && (_githubStats?['public_repos'] ?? 0) > 10) badges.add(_badge('OSS Contributor'));
    if (badges.isEmpty) badges.add(_badge('Getting Started'));
    return badges;
  }

  Widget _badge(String text) => Chip(label: Text(text), backgroundColor: Theme.of(context).colorScheme.secondaryContainer);

  Future<void> _exportPdf() async {
    if (_aiSummary == null) return;
    final stats = _buildStats();
    final pdf = pw.Document();
    pw.MemoryImage? avatar;
    if (_profilePicUrl != null && _profilePicUrl!.startsWith('http')) {
      try {
        final resp = await http.get(Uri.parse(_profilePicUrl!));
        if (resp.statusCode == 200) {
          avatar = pw.MemoryImage(resp.bodyBytes);
        }
      } catch (_) {}
    }
    // Build tag string
    final tagEntries = (stats['tags'] as Map<String,int>).entries.toList()
      ..sort((a,b)=>b.value.compareTo(a.value));
    final topTags = tagEntries.take(15).map((e)=>'${e.key} (${e.value})').join(', ');
    final badges = _buildBadges(stats).map((w)=> (w as Chip).label is Text ? ((w.label as Text).data ?? '') : '').where((s)=>s.isNotEmpty).join(' • ');
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin:  pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (avatar != null) pw.Container(
                width: 72, height: 72,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  image: pw.DecorationImage(image: avatar!, fit: pw.BoxFit.cover),
                ),
              ),
              if (avatar != null) pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_username ?? 'Developer', style:  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(_auth.currentUser?.email ?? '', style:  pw.TextStyle(color: PdfColors.grey600)),
                    if (badges.isNotEmpty) pw.Padding(
                      padding:  pw.EdgeInsets.only(top: 8),
                      child: pw.Text('Badges: $badges', style:  pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey800)),
                    ),
                  ],
                ),
              )
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding:  pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _statBlock('Discussions', stats['discussionCount'].toString()),
                _statBlock('Replies', stats['replyCount'].toString()),
                _statBlock('Explore', stats['explorePostCount'].toString()),
                _statBlock('Tags', stats['tags'].length.toString()),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Top Tags', style:  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(topTags.isEmpty ? 'No tags yet.' : topTags),
          if (_githubStats != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('GitHub Overview', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Public Repos: ${_githubStats?['public_repos']}'),
            pw.Bullet(text: 'Followers: ${_githubStats?['followers']} • Following: ${_githubStats?['following']}'),
            if (_githubStats?['primary_language'] != null) pw.Bullet(text: 'Primary Language: ${_githubStats?['primary_language']}'),
            if ((_githubStats?['languages']) is Map && (_githubStats!['languages'] as Map).isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Languages:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              _buildPdfLanguageChips((_githubStats!['languages'] as Map).cast<String,int>()),
            ],
          ],
          pw.SizedBox(height: 20),
          pw.Text('AI Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(_aiSummary ?? ''),
          pw.SizedBox(height: 24),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Generated ${DateTime.now().toIso8601String()}', style:  pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
        ],
      ),
    );
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/portfolio_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'My Developer Portfolio');
  }

  pw.Widget _statBlock(String label, String value) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  // Widget _buildProfileHeader(ThemeData theme) {
  //   final stats = _buildStats();
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [
  //           theme.colorScheme.primaryContainer.withOpacity(0.8),
  //           theme.colorScheme.secondaryContainer.withOpacity(0.75),
  //         ],
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //       ),
  //       borderRadius: BorderRadius.circular(28),
  //       boxShadow: [
  //         BoxShadow(
  //           color: theme.colorScheme.primary.withOpacity(0.15),
  //           blurRadius: 24,
  //           offset: const Offset(0, 10),
  //         )
  //       ],
  //     ),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         _avatarWidget(),
  //         const SizedBox(width: 20),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 crossAxisAlignment: CrossAxisAlignment.center,
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       _username ?? 'Developer',
  //                       style: theme.textTheme.titleLarge?.copyWith(
  //                         fontWeight: FontWeight.w800,
  //                         letterSpacing: .3,
  //                       ),
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                   if (_githubUsername != null && _githubUsername!.isNotEmpty) IconButton(
  //                     tooltip: 'Open GitHub Profile',
  //                     icon: const Icon(Icons.open_in_new, size: 20),
  //                     onPressed: () async {
  //                       final url = Uri.parse('https://github.com/$_githubUsername');
  //                       if (await canLaunchUrl(url)) {
  //                         await launchUrl(url, mode: LaunchMode.externalApplication);
  //                       }
  //                     },
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 _profileEmail ?? _auth.currentUser?.email ?? '',
  //                 style: theme.textTheme.bodySmall?.copyWith(
  //                   color: theme.colorScheme.onSurface.withOpacity(.75),
  //                 ),
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               if (_userBio != null && _userBio!.trim().isNotEmpty) ...[
  //                 const SizedBox(height: 6),
  //                 Text(
  //                   _userBio!,
  //                   style: theme.textTheme.bodySmall,
  //                   maxLines: 3,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ],
  //               if (_userCreated != null) ...[
  //                 const SizedBox(height: 6),
  //                 Text(
  //                   'Joined: ${_userCreated!.year}-${_userCreated!.month.toString().padLeft(2,'0')}-${_userCreated!.day.toString().padLeft(2,'0')}',
  //                   style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6)),
  //                 ),
  //               ],
  //               const SizedBox(height: 10),
  //               Wrap(
  //                 spacing: 6,
  //                 runSpacing: 6,
  //                 children: _buildBadges(stats).take(6).toList(),
  //               ),
  //               const SizedBox(height: 16),
  //               Row(
  //                 children: [
  //                   _miniStat(theme, 'Discussions', stats['discussionCount'].toString(), Icons.forum_outlined),
  //                   _miniDivider(),
  //                   _miniStat(theme, 'Replies', stats['replyCount'].toString(), Icons.reply_outlined),
  //                   _miniDivider(),
  //                   _miniStat(theme, 'Explore', stats['explorePostCount'].toString(), Icons.explore_outlined),
  //                 ],
  //               )
  //               ,if (_githubStats != null) ...[
  //                 const SizedBox(height: 18),
  //                 Container(
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: theme.colorScheme.surface.withOpacity(.35),
  //                     borderRadius: BorderRadius.circular(20),
  //                   ),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Row(
  //                         children: [
  //                           Icon(Icons.code_outlined, size: 18, color: theme.colorScheme.primary),
  //                           const SizedBox(width: 6),
  //                           Text('GitHub', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
  //                           const Spacer(),
  //                           if (_githubStats?['created_at'] != null) Text('Since ${(_githubStats!['created_at'] as String).substring(0,4)}', style: theme.textTheme.labelSmall),
  //                         ],
  //                       ),
  //                       const SizedBox(height: 10),
  //                       Wrap(
  //                         spacing: 10,
  //                         runSpacing: 10,
  //                         children: [
  //                           _ghStatPill(theme, Icons.book_outlined, 'Repos', (_githubStats?['public_repos'] ?? 0).toString()),
  //                           _ghStatPill(theme, Icons.people_alt_outlined, 'Followers', (_githubStats?['followers'] ?? 0).toString()),
  //                           _ghStatPill(theme, Icons.person_outline, 'Following', (_githubStats?['following'] ?? 0).toString()),
  //                           if (_githubStats?['primary_language'] != null)
  //                             _ghStatPill(theme, Icons.language_outlined, 'Primary', _githubStats?['primary_language']),
  //                         ],
  //                       ),
  //                       if ((_githubStats?['languages']) is Map && (_githubStats!['languages'] as Map).isNotEmpty) ...[
  //                         const SizedBox(height: 14),
  //                         _languageDistribution(theme, (_githubStats!['languages'] as Map).cast<String,int>()),
  //                       ]
  //                     ],
  //                   ),
  //                 )
  //               ]
  //             ],
  //           ),
  //         )
  //       ],
  //     ),
  //   );
  // }
  Widget _buildProfileHeader(ThemeData theme) {
    final stats = _buildStats();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withOpacity(0.8),
                theme.colorScheme.secondaryContainer.withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: isMobile
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatarWidget(),
              const SizedBox(height: 12),
              _profileInfo(theme, stats, isMobile),
            ],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatarWidget(),
              const SizedBox(width: 20),
              Expanded(child: _profileInfo(theme, stats, isMobile)),
            ],
          ),
        );
      },
    );
  }

  Widget _profileInfo(ThemeData theme, Map<String, dynamic> stats, bool isMobile) {
    return Column(
      crossAxisAlignment:
      isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _username ?? 'Developer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: isMobile ? TextAlign.center : TextAlign.start,
              ),
            ),
            if (!isMobile &&
                _githubUsername != null &&
                _githubUsername!.isNotEmpty)
              IconButton(
                tooltip: 'Open GitHub Profile',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () async {
                  final url = Uri.parse('https://github.com/$_githubUsername');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
        if (_profileEmail != null || _auth.currentUser?.email != null)
          Text(
            _profileEmail ?? _auth.currentUser?.email ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(.75),
            ),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
          ),
        if (_userBio != null && _userBio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _userBio!,
            style: theme.textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
          ),
        ],
        if (_userCreated != null) ...[
          const SizedBox(height: 6),
          Text(
            'Joined: ${_userCreated!.year}-${_userCreated!.month.toString().padLeft(2, '0')}-${_userCreated!.day.toString().padLeft(2, '0')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(.6),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _buildBadges(stats).take(6).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            _miniStat(theme, 'Discussions', stats['discussionCount'].toString(), Icons.forum_outlined),
            _miniDivider(),
            _miniStat(theme, 'Replies', stats['replyCount'].toString(), Icons.reply_outlined),
            _miniDivider(),
            _miniStat(theme, 'Explore', stats['explorePostCount'].toString(), Icons.explore_outlined),
          ],
        ),
          if (_githubStats != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('GitHub', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (_githubStats?['created_at'] != null) Text('Since ${(_githubStats!['created_at'] as String).substring(0,4)}', style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ghStatPill(theme, Icons.book_outlined, 'Repos', (_githubStats?['public_repos'] ?? 0).toString()),
                      _ghStatPill(theme, Icons.people_alt_outlined, 'Followers', (_githubStats?['followers'] ?? 0).toString()),
                      _ghStatPill(theme, Icons.person_outline, 'Following', (_githubStats?['following'] ?? 0).toString()),
                      if (_githubStats?['primary_language'] != null)
                        _ghStatPill(theme, Icons.language_outlined, 'Primary', _githubStats?['primary_language']),
                    ],
                  ),
                  if ((_githubStats?['languages']) is Map && (_githubStats!['languages'] as Map).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _languageDistribution(theme, (_githubStats!['languages'] as Map).cast<String,int>()),
                  ]
                ],
              ),
            )
          ]
        ],

    );
  }


  Widget _miniDivider() => Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white24);

  Widget _miniStat(ThemeData theme, String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.7)))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _avatarWidget() {
    final url = _profilePicUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(60),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.white.withOpacity(.15),
            Colors.white.withOpacity(.05)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: url != null && url.startsWith('http')
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (c, e, st) => _avatarFallback(),
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    (progress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                        ),
                      ),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    final initials = (_username ?? 'User').trim().isNotEmpty
        ? _username!.trim().split(RegExp(r'\s+')).take(2).map((e) => e[0].toUpperCase()).join()
        : 'U';
    return Container(
      color: Colors.black12,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _headerStat(ThemeData theme, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _headerDivider() => Container(width: 1, height: 32, color: Colors.white24, margin:  EdgeInsets.symmetric(horizontal: 8));

  Future<void> _shareSummary() async {
    if (_aiSummary == null) return; await Share.share(_aiSummary!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return  Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final stats = _buildStats();
  return Scaffold(
      appBar: AppBar(

        title:  Text('Developer Portfolio'),
        actions: [
          // IconButton(
          //   tooltip: 'AI Summary',
          //   onPressed: _aiLoading ? null : _generateAISummary,
          //   icon: _aiLoading ?  SizedBox(width:20,height:20,child: CircularProgressIndicator(strokeWidth:2)) :  Icon(Icons.auto_fix_high),
          // ),
          if (_aiSummary != null) IconButton(
            tooltip: 'Edit',
            icon: Icon(_editing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_editing && _editController.text.isNotEmpty) {
                setState(() { _aiSummary = _editController.text; });
                _storeHistory(_aiSummary!);
              }
              setState(() { _editing = !_editing; });
            },
          ),
          if (_aiSummary != null) IconButton(
            tooltip: 'Copy',
            icon:  Icon(Icons.copy_all),
            onPressed: () async { await Clipboard.setData(ClipboardData(text: _aiSummary!)); },
          ),
          if (_aiSummary != null) IconButton(
            tooltip: 'Share',
            icon:  Icon(Icons.share),
            onPressed: _shareSummary,
          ),
          if (_aiSummary != null) IconButton(
            tooltip: 'Export PDF',
            icon:  Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: Padding(
        padding:  EdgeInsets.all(12.0),
        child: ListView(
          children: [
            _buildProfileHeader(theme),
            const SizedBox(height: 20),
            const SizedBox(height: 12),
            _collapsibleCard(
              theme: theme,
              title: 'Overview',
              expanded: _overviewExpanded,
              onToggle: () => setState(() => _overviewExpanded = !_overviewExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    _statChip('Discussions', stats['discussionCount'].toString()),
                    _statChip('Explore Posts', stats['explorePostCount'].toString()),
                    _statChip('Replies', stats['replyCount'].toString()),
                    _statChip('Unique Tags', stats['tags'].length.toString()),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: _buildBadges(stats)),
                ],
              ),
            ),
            if (stats['tags'] is Map && (stats['tags'] as Map).isNotEmpty)
              _collapsibleCard(
                theme: theme,
                title: 'Top Tags',
                expanded: _tagsExpanded,
                onToggle: () => setState(() => _tagsExpanded = !_tagsExpanded),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildTopTagChips((stats['tags'] as Map).cast<String, int>()),
                ),
              ),
            if (_githubStats != null)
              _collapsibleCard(
                theme: theme,
                title: 'GitHub Analytics (Detailed)',
                expanded: _githubExpanded,
                onToggle: () => setState(() => _githubExpanded = !_githubExpanded),
                child: _detailedGithubSection(theme),
              ),
            if (_aiSummary != null) Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.55),
                      theme.colorScheme.secondaryContainer.withOpacity(0.55),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // subtle overlay pattern using blurred backdrop
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child:  SizedBox(),
                      ),
                    ),
                    Padding(
                      padding:  EdgeInsets.fromLTRB(16, 14, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding:  EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary
                                  ]),
                                ),
                                child:  Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                              ),
                               SizedBox(width: 12),
                              Expanded(
                                child: Text('AI Generated Summary',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: _summaryExpanded ? 'Collapse' : 'Expand',
                                icon: Icon(_summaryExpanded ? Icons.expand_less : Icons.expand_more),
                                onPressed: () => setState(()=> _summaryExpanded = !_summaryExpanded),
                              ),
                            ],
                          ),
                           SizedBox(height: 4),
                          AnimatedCrossFade(
                            firstChild: _buildSummaryContent(theme, expanded: false),
                            secondChild: _buildSummaryContent(theme, expanded: true),
                            crossFadeState: _summaryExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration:  Duration(milliseconds: 280),
                          ),
                           SizedBox(height: 12),
                          Row(
                            children: [
                              if (!_editing) Tooltip(
                                message: 'Edit',
                                child: IconButton(
                                  icon:  Icon(Icons.edit_note_rounded),
                                  onPressed: () {
                                    setState(()=> _editing = true);
                                  },
                                ),
                              ),
                              if (_editing) Tooltip(
                                message: 'Save Edits',
                                child: IconButton(
                                  icon:  Icon(Icons.check_circle_outline),
                                  onPressed: () {
                                    if (_editController.text.trim().isNotEmpty) {
                                      setState(()=> _aiSummary = _editController.text.trim());
                                      _storeHistory(_aiSummary!);
                                    }
                                    setState(()=> _editing = false);
                                  },
                                ),
                              ),
                              Tooltip(
                                message: 'Copy',
                                child: IconButton(
                                  icon:  Icon(Icons.copy_all_outlined),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: _aiSummary!));
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Summary copied')));
                                  },
                                ),
                              ),
                              Tooltip(
                                message: 'Regenerate',
                                child: IconButton(
                                  icon:  Icon(Icons.refresh_rounded),
                                  onPressed: _aiLoading ? null : _generateAISummary,
                                ),
                              ),
                              Tooltip(
                                message: 'Export PDF',
                                child: IconButton(
                                  icon:  Icon(Icons.picture_as_pdf_outlined),
                                  onPressed: _exportPdf,
                                ),
                              ),
                               Spacer(),
                              if (_aiLoading)  SizedBox(height:20,width:20, child: CircularProgressIndicator(strokeWidth:2)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_aiSummary == null) Padding(
              padding:  EdgeInsets.symmetric(vertical: 8),
              child: Text('Tap the magic wand icon to generate an AI portfolio summary.', style: theme.textTheme.bodySmall),
            ),
             SizedBox(height: 16),
            Text('Recent Discussions', style: theme.textTheme.titleMedium),
             SizedBox(height: 8),
            ..._discussions.take(5).map((d)=>ListTile(
              leading:  Icon(Icons.forum_outlined),
              title: Text(d['Title'] ?? 'Untitled', maxLines:1, overflow: TextOverflow.ellipsis),
              subtitle: Text((d['Description'] ?? '').toString(), maxLines:2, overflow: TextOverflow.ellipsis),
            )),
             SizedBox(height: 16),
            Text('Recent Explore Posts', style: theme.textTheme.titleMedium),
             SizedBox(height: 8),
            ..._explorePosts.take(5).map((e)=>ListTile(
              leading:  Icon(Icons.article_outlined),
              title: Text(e['Title'] ?? 'Untitled', maxLines:1, overflow: TextOverflow.ellipsis),
              subtitle: Text((e['Description'] ?? '').toString(), maxLines:2, overflow: TextOverflow.ellipsis),
            )),
             SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  List<Widget> _buildTopTagChips(Map<String,int> tagMap) {
    final entries = tagMap.entries.toList();
    entries.sort((a,b)=>b.value.compareTo(a.value));
    return entries.take(12).map((e)=>Chip(label: Text('${e.key} (${e.value})'))).toList();
  }

  List<Widget> _buildLanguageChips(Map<String,int> langCounts) {
    final entries = langCounts.entries.toList();
    entries.sort((a,b)=>b.value.compareTo(a.value));
    final total = entries.fold<int>(0,(p,e)=>p+e.value);
    return entries.take(12).map((e) {
      final pct = total>0 ? ((e.value/total)*100).toStringAsFixed(0) : '0';
      return Chip(label: Text('${e.key} $pct%'));
    }).toList();
  }

  Widget _buildSummaryContent(ThemeData theme, {required bool expanded}) {
    if (_editing) {
      return TextField(
        controller: _editController,
        maxLines: expanded ? 18 : 5,
        decoration:  InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Edit AI summary...'
        ),
      );
    }
    final text = _aiSummary ?? '';
    final truncated = !expanded && text.length > 650 ? text.substring(0, 650) + '\n... (expand to view more)' : text;
    return MarkdownBody(
      data: truncated,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        p: theme.textTheme.bodyMedium,
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.3),
          border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _collapsibleCard({required ThemeData theme, required String title, required bool expanded, required VoidCallback onToggle, required Widget child}) {
    return AnimatedContainer(
      duration:  Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin:  EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceVariant.withOpacity(0.5),
            theme.colorScheme.primaryContainer.withOpacity(0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset:  Offset(0,6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding:  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(expanded ? Icons.keyboard_arrow_down : Icons.chevron_right_rounded, size: 22, color: theme.colorScheme.primary),
                     SizedBox(width: 6),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    AnimatedSwitcher(
                      duration:  Duration(milliseconds: 200),
                      transitionBuilder: (c, a)=> RotationTransition(turns: a, child: c),
                      child: Icon(expanded ? Icons.expand_less : Icons.expand_more, key: ValueKey(expanded), color: theme.colorScheme.primary),
                    )
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild:  SizedBox.shrink(),
              secondChild: Padding(
                padding:  EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration:  Duration(milliseconds: 260),
            )
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfLanguageChips(Map<String,int> langCounts) {
    final entries = langCounts.entries.toList();
    entries.sort((a,b)=>b.value.compareTo(a.value));
    final total = entries.fold<int>(0,(p,e)=>p+e.value);
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.take(15).map((e){
        final pct = total>0 ? ((e.value/total)*100).toStringAsFixed(0) : '0';
        return pw.Container(
          padding:  pw.EdgeInsets.symmetric(horizontal:8, vertical:4),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
          ),
          child: pw.Text('${e.key} $pct%', style:  pw.TextStyle(fontSize: 8)),
        );
      }).toList(),
    );
  }

  // --- Added GitHub enhanced UI helpers ---
  Widget _ghStatPill(ThemeData theme, IconData icon, String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
          Text('$label: ', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(value ?? '-', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _languageDistribution(ThemeData theme, Map<String,int> langs) {
    final entries = langs.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final total = entries.fold<int>(0,(p,e)=>p+e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart_outline, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Languages', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ...entries.take(8).map((e){
          final pct = total>0 ? (e.value/total) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(.35),
                      valueColor: AlwaysStoppedAnimation(
                        Color((e.key.hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(.85),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 70, child: Text(e.key, style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Text('${(pct*100).toStringAsFixed(0)}%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _detailedGithubSection(ThemeData theme) {
    if (_githubStats == null) return const SizedBox.shrink();
    final langs = (_githubStats?['languages']) is Map ? (_githubStats!['languages'] as Map).cast<String,int>() : <String,int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ghStatPill(theme, Icons.book_outlined, 'Repos', (_githubStats?['public_repos'] ?? 0).toString()),
            _ghStatPill(theme, Icons.people_outline, 'Followers', (_githubStats?['followers'] ?? 0).toString()),
            _ghStatPill(theme, Icons.person_outline, 'Following', (_githubStats?['following'] ?? 0).toString()),
            if (_githubStats?['primary_language'] != null)
              _ghStatPill(theme, Icons.language_outlined, 'Primary', _githubStats?['primary_language']),
            if (_githubStats?['created_at'] != null)
              _ghStatPill(theme, Icons.calendar_month_outlined, 'Since', (_githubStats!['created_at'] as String).substring(0,4)),
          ],
        ),
        const SizedBox(height: 18),
        if (langs.isNotEmpty) _languageDistribution(theme, langs) else Text('No language data.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
