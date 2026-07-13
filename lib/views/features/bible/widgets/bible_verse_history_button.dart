import 'package:church_presenter/db/database_helper.dart';
import 'package:flutter/material.dart';
import '../utils/bible_history_format.dart';

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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final grouped = groupHistoryByDay(
              verseHistory,
              newestFirst: _historySortNewest,
            );
            final days = grouped.keys.toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Verse History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: days.length,
                        itemBuilder: (context, dayIndex) {
                          final day = days[dayIndex];
                          final entries = grouped[day]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  formatHistoryDayLabel(day),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                    formatHistoryTime(
                                      entry['timestamp'] as String,
                                    ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await DatabaseHelper.instance
                                    .clearBibleHistory();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
