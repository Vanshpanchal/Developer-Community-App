import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/url_helper.dart';

/// Text with tappable http(s) links.
///
/// Owns its [TapGestureRecognizer]s and disposes them, instead of creating
/// new, never-disposed recognizers on every build (audit BUG-19).
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.selectable = false,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  /// Renders with [SelectableText] so users can copy the text.
  final bool selectable;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final _urlRegex = RegExp(r'https?://[^\s]+');

  final List<TapGestureRecognizer> _recognizers = [];
  List<_Segment> _segments = const [];

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _parse();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _parse() {
    _disposeRecognizers();
    final segments = <_Segment>[];
    var last = 0;
    for (final match in _urlRegex.allMatches(widget.text)) {
      if (match.start > last) {
        segments.add(_Segment(widget.text.substring(last, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openExternalUrl(url);
      _recognizers.add(recognizer);
      segments.add(_Segment(url, recognizer));
      last = match.end;
    }
    if (last < widget.text.length) {
      segments.add(_Segment(widget.text.substring(last)));
    }
    _segments = segments;
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final span = TextSpan(
      style: widget.style,
      children: [
        for (final s in _segments)
          TextSpan(
            text: s.text,
            style: s.recognizer == null ? null : linkStyle,
            recognizer: s.recognizer,
          ),
      ],
    );
    if (widget.selectable) {
      return SelectableText.rich(span, maxLines: widget.maxLines);
    }
    return Text.rich(
      span,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

class _Segment {
  const _Segment(this.text, [this.recognizer]);
  final String text;
  final TapGestureRecognizer? recognizer;
}
