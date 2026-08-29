/// Formats a timestamp into a human-friendly relative time string.
///
/// Rules:
/// - under 1 minute: "just now"
/// - under 60 min: "Xm ago"
/// - under 48h: "Xh ago"
/// - beyond that: "X days ago"
String formatRelativeTime(DateTime? value) {
  if (value == null) return 'unknown';
  final Duration diff = DateTime.now().difference(value);
  if (diff.isNegative || diff.inMinutes < 1) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 48) {
    return '${diff.inHours}h ago';
  }
  final int days = diff.inDays;
  return '$days days ago';
}
