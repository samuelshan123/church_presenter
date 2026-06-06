import 'package:church_presenter/db/database_helper.dart';
import 'package:flutter/material.dart';

typedef BibleVerseHistoryEntrySelected =
    void Function(Map<String, dynamic> entry);

class BibleVerseHistoryButton extends StatefulWidget {
  final BibleVerseHistoryEntrySelected onEntrySelected;

  const BibleVerseHistoryButton({super.key, required this.onEntrySelected});

  @override
  State<BibleVerseHistoryButton> createState() =>
      _BibleVerseHistoryButtonState();
}

class _BibleVerseHistoryButtonState extends State<BibleVerseHistoryButton> {
  bool _historySortNewest = true;

  Future<void> _showHistoryDialog() async {
    final verseHistory = await DatabaseHelper.instance.getBibleHistory();

    if (!mounted) return;

    if (verseHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verse history yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    String formatDayLabel(String dayKey) {
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

    String formatTime(String timestamp) {
      final dt = DateTime.parse(timestamp).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    }

    Map<String, List<Map<String, dynamic>>> buildGrouped(bool newestFirst) {
      final entries = newestFirst ? verseHistory : verseHistory.reversed;
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final entry in entries) {
        final dt = DateTime.parse(entry['timestamp'] as String).toLocal();
        final dayKey =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(dayKey, () => []).add(entry);
      }
      return grouped;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final grouped = buildGrouped(_historySortNewest);
            final days = grouped.keys.toList();
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Verse History')),
                  Tooltip(
                    message: _historySortNewest
                        ? 'Newest first'
                        : 'Oldest first',
                    child: TextButton.icon(
                      icon: Icon(
                        _historySortNewest
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 16,
                      ),
                      label: Text(
                        _historySortNewest ? 'Newest' : 'Oldest',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(
                          () => _historySortNewest = !_historySortNewest,
                        );
                        setDialogState(() {});
                      },
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: days.length,
                  itemBuilder: (context, dayIndex) {
                    final day = days[dayIndex];
                    final entries = grouped[day]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            formatDayLabel(day),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        ...entries.map((entry) {
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${entry['bookTamil']} ${entry['chapter']}:${entry['verseNumber']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              formatTime(entry['timestamp'] as String),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onEntrySelected(entry);
                            },
                          );
                        }),
                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await DatabaseHelper.instance.clearBibleHistory();
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.history),
      tooltip: 'Verse History',
      onPressed: _showHistoryDialog,
    );
  }
}
