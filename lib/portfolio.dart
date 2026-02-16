import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'utils/app_theme.dart';
import 'widgets/modern_widgets.dart';
import 'ThemeController.dart';
import 'package:get/get.dart';
import 'utils/app_snackbar.dart';

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
  // ignore: unused_field
  String? _error;
  bool _aiLoading = false;
  String? _aiSummary;
  bool _editing = false;
  final _editController = TextEditingController();
  // ignore: unused_field
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _githubStats;
  String? _profilePicUrl;
  String? _username;
  bool _summaryExpanded = false;
  bool _tagsExpanded = true;
  bool _githubExpanded = true;
  bool _discussionsExpanded = true;
  bool _postsExpanded = true;
  String? _githubUsername;
  String? _userBio;
  DateTime? _userCreated;
  String?
      _profileEmail; // email of viewed profile (may differ from signed-in user)

  bool get _isSelf {
    final cu = _auth.currentUser;
    if (cu == null) return false;
    return widget.userId == null || widget.userId == cu.uid;
  }

  List<Map<String, dynamic>> _discussions = [];
  List<Map<String, dynamic>> _explorePosts = [];
  List<Map<String, dynamic>> _replies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHistory();
  }

  Future<void> _loadData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _error = 'Not authenticated';
        _loading = false;
      });
      return;
    }
    final targetUid = widget.userId ?? currentUser.uid;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(targetUid)
          .get();
      final data = userDoc.data() ?? {};
      _profilePicUrl = data['profilePicture'] as String?;
      _username = data['Username'] as String? ??
          data['username'] as String? ??
          'Developer';
      _profileEmail =
          data['Email'] as String? ?? (_isSelf ? currentUser.email : null);
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
      final allDisc = await FirebaseFirestore.instance
          .collection('Discussions')
          .limit(60)
          .get();
      _replies.clear();
      final replyFutures = <Future>[];
      for (final d in allDisc.docs) {
        replyFutures.add(FirebaseFirestore.instance
            .collection('Discussions')
            .doc(d.id)
            .collection('Replies')
            .where('uid', isEqualTo: targetUid)
            .get()
            .then((qs) {
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
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _generateAISummary() async {
    if (_aiLoading) return; // guard
    setState(() {
      _aiLoading = true;
      _aiSummary = null;
    });
    try {
      final user = _auth.currentUser;
      final stats = _buildStats();
      await _maybeFetchGithub();
      final mergedStats = {
        ...stats,
        if (_githubStats != null) 'github': _githubStats
      };
      final summary = await AIService().generatePortfolioSummary(
        stats: mergedStats,
        github: _githubStats,
        userHandle: user?.email,
      );
      if (summary == AIService.missingKeyMessage) {
        if (mounted) _showMissingKeyDialog();
      } else if (mounted) {
        setState(() {
          _aiSummary = summary;
          _editController.text = summary;
        });
        _storeHistory(summary);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _aiSummary = 'AI summary failed: $e';
        });
    } finally {
      if (mounted)
        setState(() {
          _aiLoading = false;
        });
    }
  }

  void _showMissingKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key Needed'),
        content: const Text(
            'To generate an AI portfolio summary, please add your Gemini API key in settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // ignore: unused_element
  String _portfolioPrompt(String userId, Map<String, dynamic> stats) {
    return 'Generate a concise markdown portfolio summary. Include sections: Profile Highlights, Tech Focus, Community Impact (discussions ${stats['discussionCount']} / answers ${stats['replyCount']}), Suggested Growth Areas, Notable Topics (list tag frequency), Contribution Level Estimate (1 line). Stats JSON: ${stats.toString()}';
  }

  Map<String, dynamic> _buildStats() {
    final tagFreq = <String, int>{};
    for (final d in _discussions) {
      final tags = (d['Tags'] as List?)?.cast<dynamic>() ?? [];
      for (final t in tags) {
        if (t is String) tagFreq[t] = (tagFreq[t] ?? 0) + 1;
      }
    }
    for (final e in _explorePosts) {
      final tags = (e['Tags'] as List?)?.cast<dynamic>() ?? [];
      for (final t in tags) {
        if (t is String) tagFreq[t] = (tagFreq[t] ?? 0) + 1;
      }
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
      final profileDoc =
          await FirebaseFirestore.instance.collection('User').doc(uid).get();
      final gh = profileDoc.data()?['github'] as String?;
      _githubUsername = gh;
      if (gh == null || gh.isEmpty) return;
      final headers = {'User-Agent': 'DevCommunityApp'};
      final userResp = await http
          .get(Uri.parse('https://api.github.com/users/$gh'), headers: headers);
      if (userResp.statusCode != 200) return;
      final data = jsonDecode(userResp.body) as Map<String, dynamic>;
      _githubStats = {
        'public_repos': data['public_repos'],
        'followers': data['followers'],
        'following': data['following'],
        'created_at': data['created_at'],
      };
      final reposResp = await http.get(
          Uri.parse(
              'https://api.github.com/users/$gh/repos?per_page=50&sort=updated'),
          headers: headers);
      if (reposResp.statusCode == 200) {
        final repos = jsonDecode(reposResp.body) as List<dynamic>;
        final langCounts = <String, int>{};
        for (final r in repos) {
          final lang = r['language'];
          if (lang is String && lang.isNotEmpty) {
            langCounts[lang] = (langCounts[lang] ?? 0) + 1;
          }
        }
        if (langCounts.isNotEmpty) {
          final sorted = langCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          _githubStats!['languages'] = langCounts;
          _githubStats!['primary_language'] = sorted.first.key;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _storeHistory(String summary) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final entry = {
      'summary': summary,
      'ts': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .collection('PortfolioHistory')
        .add(entry);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final qs = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .collection('PortfolioHistory')
        .orderBy('ts', descending: true)
        .limit(10)
        .get();
    setState(() {
      _history = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    });
  }

  List<Widget> _buildBadges(Map<String, dynamic> stats) {
    final badges = <Widget>[];
    if (stats['discussionCount'] > 5) badges.add(_badge('Active Discussant'));
    if (stats['replyCount'] > 10) badges.add(_badge('Helper'));
    final tags = stats['tags'] as Map<String, int>;
    if (tags.values.any((c) => c >= 5)) badges.add(_badge('Tag Specialist'));
    if (_githubStats != null && (_githubStats?['public_repos'] ?? 0) > 10)
      badges.add(_badge('OSS Contributor'));
    if (badges.isEmpty) badges.add(_badge('Getting Started'));
    return badges;
  }

  Widget _badge(String text) => Chip(
      label: Text(text),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer);

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
    final tagEntries = (stats['tags'] as Map<String, int>).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags =
        tagEntries.take(15).map((e) => '${e.key} (${e.value})').join(', ');
    final badges = _buildBadges(stats)
        .map((w) =>
            (w as Chip).label is Text ? ((w.label as Text).data ?? '') : '')
        .where((s) => s.isNotEmpty)
        .join(' • ');
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (avatar != null)
                pw.Container(
                  width: 72,
                  height: 72,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    image:
                        pw.DecorationImage(image: avatar, fit: pw.BoxFit.cover),
                  ),
                ),
              if (avatar != null) pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_username ?? 'Developer',
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(_auth.currentUser?.email ?? '',
                        style: pw.TextStyle(color: PdfColors.grey600)),
                    if (badges.isNotEmpty)
                      pw.Padding(
                        padding: pw.EdgeInsets.only(top: 8),
                        child: pw.Text('Badges: $badges',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.blueGrey800)),
                      ),
                  ],
                ),
              )
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: pw.EdgeInsets.all(12),
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
          pw.Text('Top Tags',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(topTags.isEmpty ? 'No tags yet.' : topTags),
          if (_githubStats != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('GitHub Overview',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Public Repos: ${_githubStats?['public_repos']}'),
            pw.Bullet(
                text:
                    'Followers: ${_githubStats?['followers']} • Following: ${_githubStats?['following']}'),
            if (_githubStats?['primary_language'] != null)
              pw.Bullet(
                  text:
                      'Primary Language: ${_githubStats?['primary_language']}'),
            if ((_githubStats?['languages']) is Map &&
                (_githubStats!['languages'] as Map).isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Languages:',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              _buildPdfLanguageChips(
                  (_githubStats!['languages'] as Map).cast<String, int>()),
            ],
          ],
          pw.SizedBox(height: 20),
          pw.Text('AI Summary',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(_aiSummary ?? ''),
          pw.SizedBox(height: 24),
          pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generated ${DateTime.now().toIso8601String()}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
        ],
      ),
    );
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/portfolio_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'My Developer Portfolio');
  }

  pw.Widget _statBlock(String label, String value) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(label,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
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
  // ignore: unused_element
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

  Widget _profileInfo(
      ThemeData theme, Map<String, dynamic> stats, bool isMobile) {
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
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            _miniStat(theme, 'Discussions', stats['discussionCount'].toString(),
                Icons.forum_outlined),
            _miniDivider(),
            _miniStat(theme, 'Replies', stats['replyCount'].toString(),
                Icons.reply_outlined),
            _miniDivider(),
            _miniStat(theme, 'Explore', stats['explorePostCount'].toString(),
                Icons.explore_outlined),
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
                    Icon(Icons.code_outlined,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('GitHub',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_githubStats?['created_at'] != null)
                      Text(
                          'Since ${(_githubStats!['created_at'] as String).substring(0, 4)}',
                          style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ghStatPill(theme, Icons.book_outlined, 'Repos',
                        (_githubStats?['public_repos'] ?? 0).toString()),
                    _ghStatPill(theme, Icons.people_alt_outlined, 'Followers',
                        (_githubStats?['followers'] ?? 0).toString()),
                    _ghStatPill(theme, Icons.person_outline, 'Following',
                        (_githubStats?['following'] ?? 0).toString()),
                    if (_githubStats?['primary_language'] != null)
                      _ghStatPill(theme, Icons.language_outlined, 'Primary',
                          _githubStats?['primary_language']),
                  ],
                ),
                if ((_githubStats?['languages']) is Map &&
                    (_githubStats!['languages'] as Map).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _languageDistribution(theme,
                      (_githubStats!['languages'] as Map).cast<String, int>()),
                ]
              ],
            ),
          )
        ]
      ],
    );
  }

  Widget _miniDivider() => Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white24);

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
                Text(value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(.7)))
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
        ? _username!
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0].toUpperCase())
            .join()
        : 'U';
    return Container(
      color: Colors.black12,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _headerStat(ThemeData theme, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _headerDivider() => Container(
      width: 1,
      height: 32,
      color: Colors.white24,
      margin: EdgeInsets.symmetric(horizontal: 8));

  Future<void> _shareSummary() async {
    if (_aiSummary == null) return;
    await Share.share(_aiSummary!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;

    if (_loading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header shimmer
                const ProfileShimmer(),
                const SizedBox(height: 20),
                // Stats cards shimmer
                const Row(
                  children: [
                    Expanded(child: StatsCardShimmer()),
                    SizedBox(width: 12),
                    Expanded(child: StatsCardShimmer()),
                    SizedBox(width: 12),
                    Expanded(child: StatsCardShimmer()),
                  ],
                ),
                const SizedBox(height: 16),
                // Content shimmer
                Expanded(child: ListShimmer(itemCount: 3)),
              ],
            ),
          ),
        ),
      );
    }
    final stats = _buildStats();
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Activity Stats',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
              ),
            ),
          ],
        ),
        actions: [
          if (_aiSummary != null)
            _buildActionButton(
              icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
              tooltip: _editing ? 'Save' : 'Edit',
              onPressed: () {
                if (_editing && _editController.text.isNotEmpty) {
                  setState(() {
                    _aiSummary = _editController.text;
                  });
                  _storeHistory(_aiSummary!);
                }
                setState(() {
                  _editing = !_editing;
                });
              },
            ),
          if (_aiSummary != null)
            _buildActionButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _aiSummary!));
                HapticFeedback.lightImpact();
                if (mounted) {
                  AppSnackbar.success('Copied to clipboard');
                }
              },
            ),
          if (_aiSummary != null)
            _buildActionButton(
              icon: Icons.share_rounded,
              tooltip: 'Share',
              onPressed: _shareSummary,
            ),
          if (_aiSummary != null)
            _buildActionButton(
              icon: Icons.picture_as_pdf_rounded,
              tooltip: 'Export PDF',
              onPressed: _exportPdf,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            _buildModernProfileHeader(theme, stats),
            const SizedBox(height: 20),

            // AI Generate Button (if no summary and viewing own profile)
            if (_isSelf && _aiSummary == null) _buildAIGenerateSection(theme),

            if (stats['tags'] is Map && (stats['tags'] as Map).isNotEmpty)
              _buildModernCollapsibleCard(
                theme: theme,
                title: 'Top Tags',
                icon: Icons.sell_rounded,
                expanded: _tagsExpanded,
                onToggle: () => setState(() => _tagsExpanded = !_tagsExpanded),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildModernTagChips(
                      (stats['tags'] as Map).cast<String, int>()),
                ),
              ),
            if (_githubStats != null)
              _buildModernCollapsibleCard(
                theme: theme,
                title: 'GitHub Analytics',
                icon: Icons.code_rounded,
                expanded: _githubExpanded,
                onToggle: () =>
                    setState(() => _githubExpanded = !_githubExpanded),
                child: _buildModernGithubSection(theme),
              ),
            if (_aiSummary != null) _buildAISummaryCard(theme),

            // const SizedBox(height: 20),
            _buildModernCollapsibleCard(
              theme: theme,
              title: 'Recent Discussions',
              icon: Icons.forum_outlined,
              expanded: _discussionsExpanded,
              onToggle: () =>
                  setState(() => _discussionsExpanded = !_discussionsExpanded),
              child: Column(
                children: _discussions.isEmpty
                    ? [
                        _buildEmptyState(
                            'No discussions yet', Icons.forum_outlined)
                      ]
                    : _discussions
                        .take(5)
                        .map((d) => _buildActivityTile(
                              title: d['Title'] ?? 'Untitled',
                              subtitle: (d['Description'] ?? '').toString(),
                              icon: Icons.forum_rounded,
                              color: AppTheme.primaryColor,
                            ))
                        .toList(),
              ),
            ),
            _buildModernCollapsibleCard(
              theme: theme,
              title: 'Recent Posts',
              icon: Icons.article_outlined,
              expanded: _postsExpanded,
              onToggle: () => setState(() => _postsExpanded = !_postsExpanded),
              child: Column(
                children: _explorePosts.isEmpty
                    ? [_buildEmptyState('No posts yet', Icons.article_outlined)]
                    : _explorePosts
                        .take(5)
                        .map((e) => _buildActivityTile(
                              title: e['Title'] ?? 'Untitled',
                              subtitle: (e['Description'] ?? '').toString(),
                              icon: Icons.article_rounded,
                              color: AppTheme.accentColor,
                            ))
                        .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildModernProfileHeader(
      ThemeData theme, Map<String, dynamic> stats) {
    final isDark = theme.brightness == Brightness.dark;
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF0F2644)]
              : [
                  primaryColor.withValues(alpha: 0.15),
                  primaryColor.withValues(alpha: 0.1)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? primaryColor.withValues(alpha: 0.3)
              : primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Avatar
              _buildModernAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _username ?? 'Developer',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (_githubUsername != null &&
                            _githubUsername!.isNotEmpty)
                          _buildGitHubButton(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profileEmail ?? _auth.currentUser?.email ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (_userBio != null && _userBio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _userBio!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_userCreated != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Joined ${_userCreated!.year}-${_userCreated!.month.toString().padLeft(2, '0')}-${_userCreated!.day.toString().padLeft(2, '0')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderStatNew(theme, 'Discussions',
                    stats['discussionCount'].toString(), Icons.forum_rounded),
                _buildStatDivider(isDark),
                _buildHeaderStatNew(theme, 'Replies',
                    stats['replyCount'].toString(), Icons.reply_rounded),
                _buildStatDivider(isDark),
                _buildHeaderStatNew(
                    theme,
                    'Posts',
                    stats['explorePostCount'].toString(),
                    Icons.explore_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAvatar() {
    final url = _profilePicUrl;
    final themeController = Get.find<ThemeController>();
    final primaryColor = themeController.primaryColor.value;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: url != null && url.startsWith('http')
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (c, e, st) => _buildModernAvatarFallback(),
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
              )
            : _buildModernAvatarFallback(),
      ),
    );
  }

  Widget _buildModernAvatarFallback() {
    final initials = (_username ?? 'User').trim().isNotEmpty
        ? _username!
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0].toUpperCase())
            .join()
        : 'U';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGitHubButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF24292E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final url = Uri.parse('https://github.com/$_githubUsername');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('GitHub',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatNew(
      ThemeData theme, String label, String value, IconData icon) {
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 85, // Fixed width based on "Discussions" being the longest label
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.white24 : Colors.black12,
    );
  }

  Widget _buildAIGenerateSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            AppTheme.accentColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Generate AI Portfolio Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let AI analyze your activity and create a personalized developer summary',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _aiLoading ? null : _generateAISummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: _aiLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_fix_high_rounded),
                        SizedBox(width: 8),
                        Text('Generate Summary',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildModernStatCard(
      String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  List<Widget> _buildModernBadges(Map<String, dynamic> stats) {
    final badges = <Map<String, dynamic>>[];

    if (stats['discussionCount'] > 5)
      badges.add({
        'label': 'Active Discussant',
        'icon': Icons.forum_rounded,
        'color': AppTheme.primaryColor
      });
    if (stats['replyCount'] > 10)
      badges.add({
        'label': 'Helper',
        'icon': Icons.volunteer_activism_rounded,
        'color': Colors.pink
      });
    final tags = stats['tags'] as Map<String, int>;
    if (tags.values.any((c) => c >= 5))
      badges.add({
        'label': 'Tag Specialist',
        'icon': Icons.sell_rounded,
        'color': Colors.orange
      });
    if (_githubStats != null && (_githubStats?['public_repos'] ?? 0) > 10)
      badges.add({
        'label': 'OSS Contributor',
        'icon': Icons.code_rounded,
        'color': AppTheme.successColor
      });
    if (badges.isEmpty)
      badges.add({
        'label': 'Getting Started',
        'icon': Icons.rocket_launch_rounded,
        'color': Colors.purple
      });

    return badges.map((badge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (badge['color'] as Color).withValues(alpha: 0.2),
              (badge['color'] as Color).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: (badge['color'] as Color).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge['icon'] as IconData,
                size: 16, color: badge['color'] as Color),
            const SizedBox(width: 6),
            Text(
              badge['label'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badge['color'] as Color,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildModernTagChips(Map<String, int> tagMap) {
    final entries = tagMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      AppTheme.primaryColor,
      AppTheme.accentColor,
      Colors.orange,
      Colors.pink,
      AppTheme.successColor,
      Colors.purple,
      Colors.teal,
    ];

    return entries.take(12).toList().asMap().entries.map((entry) {
      final color = colors[entry.key % colors.length];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.value.key,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.value.value}',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildModernCollapsibleCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(icon, size: 18, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernGithubSection(ThemeData theme) {
    if (_githubStats == null) return const SizedBox.shrink();
    final langs = (_githubStats?['languages']) is Map
        ? (_githubStats!['languages'] as Map).cast<String, int>()
        : <String, int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildGithubStatChip(
                Icons.book_outlined,
                'Repos',
                (_githubStats?['public_repos'] ?? 0).toString(),
                AppTheme.primaryColor),
            _buildGithubStatChip(Icons.people_alt_outlined, 'Followers',
                (_githubStats?['followers'] ?? 0).toString(), Colors.pink),
            _buildGithubStatChip(Icons.person_add_outlined, 'Following',
                (_githubStats?['following'] ?? 0).toString(), Colors.orange),
            if (_githubStats?['primary_language'] != null)
              _buildGithubStatChip(Icons.code_rounded, 'Primary',
                  _githubStats?['primary_language'], AppTheme.successColor),
            if (_githubStats?['created_at'] != null)
              _buildGithubStatChip(
                  Icons.calendar_today_rounded,
                  'Since',
                  (_githubStats!['created_at'] as String).substring(0, 4),
                  Colors.purple),
          ],
        ),
        if (langs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Language Distribution',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildModernLanguageDistribution(theme, langs),
        ],
      ],
    );
  }

  Widget _buildGithubStatChip(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: color.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernLanguageDistribution(
      ThemeData theme, Map<String, int> langs) {
    final entries = langs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (p, e) => p + e.value);
    final colors = [
      AppTheme.primaryColor,
      Colors.orange,
      AppTheme.successColor,
      Colors.pink,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: entries.take(6).toList().asMap().entries.map((entry) {
        final e = entry.value;
        final color = colors[entry.key % colors.length];
        final pct = total > 0 ? (e.value / total) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e.key,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAISummaryCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF0F2644)]
              : [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.accentColor.withValues(alpha: 0.08)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Generated Summary',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Powered by Gemini',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _summaryExpanded = !_summaryExpanded),
                      icon: AnimatedRotation(
                        turns: _summaryExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedCrossFade(
                  firstChild: _buildSummaryMarkdown(theme, expanded: false),
                  secondChild: _buildSummaryMarkdown(theme, expanded: true),
                  crossFadeState: _summaryExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                const SizedBox(height: 16),
                // Action buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSummaryAction(
                        icon:
                            _editing ? Icons.check_rounded : Icons.edit_rounded,
                        label: _editing ? 'Save' : 'Edit',
                        onPressed: () {
                          if (_editing &&
                              _editController.text.trim().isNotEmpty) {
                            setState(
                                () => _aiSummary = _editController.text.trim());
                            _storeHistory(_aiSummary!);
                          }
                          setState(() => _editing = !_editing);
                        },
                      ),
                      _buildSummaryAction(
                        icon: Icons.refresh_rounded,
                        label: 'Regenerate',
                        onPressed: _aiLoading ? null : _generateAISummary,
                      ),
                      _buildSummaryAction(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: _aiSummary!));
                          HapticFeedback.lightImpact();
                        },
                      ),
                      _buildSummaryAction(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF',
                        onPressed: _exportPdf,
                      ),
                      if (_aiLoading)
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryAction({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMarkdown(ThemeData theme, {required bool expanded}) {
    if (_editing) {
      return TextField(
        controller: _editController,
        maxLines: expanded ? 18 : 5,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          hintText: 'Edit AI summary...',
          filled: true,
          fillColor: theme.brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.5),
        ),
      );
    }
    final text = _aiSummary ?? '';
    final truncated = !expanded && text.length > 650
        ? '${text.substring(0, 650)}\n... (tap to expand)'
        : text;

    return MarkdownBody(
      data: truncated,
      styleSheet: AppMarkdownStyles.getCodeStyle(context),
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _statChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  // ignore: unused_element
  List<Widget> _buildTopTagChips(Map<String, int> tagMap) {
    final entries = tagMap.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(12)
        .map((e) => Chip(label: Text('${e.key} (${e.value})')))
        .toList();
  }

  // ignore: unused_element
  List<Widget> _buildLanguageChips(Map<String, int> langCounts) {
    final entries = langCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (p, e) => p + e.value);
    return entries.take(12).map((e) {
      final pct =
          total > 0 ? ((e.value / total) * 100).toStringAsFixed(0) : '0';
      return Chip(label: Text('${e.key} $pct%'));
    }).toList();
  }

  // ignore: unused_element
  Widget _buildSummaryContent(ThemeData theme, {required bool expanded}) {
    if (_editing) {
      return TextField(
        controller: _editController,
        maxLines: expanded ? 18 : 5,
        decoration: InputDecoration(
            border: OutlineInputBorder(), hintText: 'Edit AI summary...'),
      );
    }
    final text = _aiSummary ?? '';
    final truncated = !expanded && text.length > 650
        ? text.substring(0, 650) + '\n... (expand to view more)'
        : text;
    return MarkdownBody(
      data: truncated,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        p: theme.textTheme.bodyMedium,
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.3),
          border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 3)),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _collapsibleCard(
      {required ThemeData theme,
      required String title,
      required bool expanded,
      required VoidCallback onToggle,
      required Widget child}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 12),
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
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                        expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.chevron_right_rounded,
                        size: 22,
                        color: theme.colorScheme.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          RotationTransition(turns: a, child: c),
                      child: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          key: ValueKey(expanded),
                          color: theme.colorScheme.primary),
                    )
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: SizedBox.shrink(),
              secondChild: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Duration(milliseconds: 260),
            )
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfLanguageChips(Map<String, int> langCounts) {
    final entries = langCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (p, e) => p + e.value);
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.take(15).map((e) {
        final pct =
            total > 0 ? ((e.value / total) * 100).toStringAsFixed(0) : '0';
        return pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
          ),
          child: pw.Text('${e.key} $pct%', style: pw.TextStyle(fontSize: 8)),
        );
      }).toList(),
    );
  }

  // --- Added GitHub enhanced UI helpers ---
  Widget _ghStatPill(
      ThemeData theme, IconData icon, String label, String? value) {
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
          Text('$label: ',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(value ?? '-', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _languageDistribution(ThemeData theme, Map<String, int> langs) {
    final entries = langs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (p, e) => p + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart_outline,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Languages',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ...entries.take(8).map((e) {
          final pct = total > 0 ? (e.value / total) : 0.0;
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
                      backgroundColor:
                          theme.colorScheme.surfaceVariant.withOpacity(.35),
                      valueColor: AlwaysStoppedAnimation(
                        Color((e.key.hashCode & 0xFFFFFF) | 0xFF000000)
                            .withOpacity(.85),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                    width: 70,
                    child: Text(e.key,
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ignore: unused_element
  Widget _detailedGithubSection(ThemeData theme) {
    if (_githubStats == null) return const SizedBox.shrink();
    final langs = (_githubStats?['languages']) is Map
        ? (_githubStats!['languages'] as Map).cast<String, int>()
        : <String, int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ghStatPill(theme, Icons.book_outlined, 'Repos',
                (_githubStats?['public_repos'] ?? 0).toString()),
            _ghStatPill(theme, Icons.people_outline, 'Followers',
                (_githubStats?['followers'] ?? 0).toString()),
            _ghStatPill(theme, Icons.person_outline, 'Following',
                (_githubStats?['following'] ?? 0).toString()),
            if (_githubStats?['primary_language'] != null)
              _ghStatPill(theme, Icons.language_outlined, 'Primary',
                  _githubStats?['primary_language']),
            if (_githubStats?['created_at'] != null)
              _ghStatPill(theme, Icons.calendar_month_outlined, 'Since',
                  (_githubStats!['created_at'] as String).substring(0, 4)),
          ],
        ),
        const SizedBox(height: 18),
        if (langs.isNotEmpty)
          _languageDistribution(theme, langs)
        else
          Text('No language data.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
