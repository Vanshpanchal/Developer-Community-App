import 'package:intl/intl.dart';

/// Short relative time for recent items ("just now", "5m ago", "3h ago",
/// "2d ago"), then a locale-aware date such as "Sep 28, 2026" (audit UX-05).
String formatRelativeDate(DateTime date, {DateTime? now, String? locale}) {
  final difference = (now ?? DateTime.now()).difference(date);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat.yMMMd(locale).format(date);
}
