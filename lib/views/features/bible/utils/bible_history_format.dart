/// Formats a `yyyy-MM-dd` day key as a human label: "Today", "Yesterday",
/// "MMM d" for the current year, or "MMM d, yyyy" otherwise.
String formatHistoryDayLabel(String dayKey) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final parts = dayKey.split('-');
  final d = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  if (d == today) return 'Today';
  if (d == yesterday) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[d.month - 1];
  if (d.year == now.year) return '$month ${d.day}';
  return '$month ${d.day}, ${d.year}';
}

/// Formats an ISO-8601 [timestamp] as a local 12-hour time, e.g. "3:45 PM".
String formatHistoryTime(String timestamp) {
  final dt = DateTime.parse(timestamp).toLocal();
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $period';
}

/// Groups [entries] (each expected to have a `timestamp` ISO-8601 key) by
/// local calendar day (`yyyy-MM-dd`), preserving the order of [entries]
/// within each day. Pass [newestFirst] `false` to group the reversed list.
Map<String, List<Map<String, dynamic>>> groupHistoryByDay(
  List<Map<String, dynamic>> entries, {
  bool newestFirst = true,
}) {
  final ordered = newestFirst ? entries : entries.reversed;
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final entry in ordered) {
    final dt = DateTime.parse(entry['timestamp'] as String).toLocal();
    final dayKey =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    grouped.putIfAbsent(dayKey, () => []).add(entry);
  }
  return grouped;
}
