import 'package:church_presenter/db/database_helper.dart';
import 'package:church_presenter/db/models/bible_book.dart';
import 'package:church_presenter/db/models/bible_verse.dart';
import 'package:church_presenter/main.dart';
import 'package:church_presenter/services/bible_service.dart';
import 'package:church_presenter/services/server_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../widgets/broadcast_info_banner.dart';
import '../../widgets/broadcast_control_bar.dart';
import '../../widgets/presenter_settings_panel.dart';

class BibleChapterScreen extends StatefulWidget {
  final BibleBook book;
  final BibleService bibleService;
  final ServerService? serverService;

  const BibleChapterScreen({
    super.key,
    required this.book,
    required this.bibleService,
    this.serverService,
  });

  @override
  State<BibleChapterScreen> createState() => _BibleChapterScreenState();
}

class _BibleChapterScreenState extends State<BibleChapterScreen> {
  int _currentChapter = 1;
  int _totalChapters = 1;
  List<BibleVerse> _verses = [];
  List<GlobalKey> _verseKeys = [];
  bool _isLoading = true;
  String? _error;
  List<BibleBook> _allBooks = [];
  BibleBook? _currentBook;
  int? _selectedVerseIndex;
  List<Map<String, dynamic>> _verseHistory = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _loadInitialData();
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load all books for book selector
      _allBooks = await widget.bibleService.loadBooks();

      // Load chapter data
      await _loadChapterData();
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChapterData({int? jumpToVerseNumber}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _selectedVerseIndex = null;
      });

      final totalChapters = await widget.bibleService.getChapterCount(
        _currentBook!.english,
      );
      final verses = await widget.bibleService.getVerses(
        _currentBook!.english,
        _currentChapter,
      );

      // Default to verse 1 (index 0), or jump to a specific verse
      int? targetIndex;
      if (jumpToVerseNumber != null) {
        final idx = verses.indexWhere(
          (v) => v.verseNumber == jumpToVerseNumber,
        );
        targetIndex = idx >= 0 ? idx : 0;
      } else {
        targetIndex = verses.isNotEmpty ? 0 : null;
      }

      setState(() {
        _totalChapters = totalChapters;
        _verses = verses;
        _verseKeys = List.generate(verses.length, (_) => GlobalKey());
        _isLoading = false;
        _selectedVerseIndex = targetIndex;
      });

      // Scroll to target verse after frame renders
      if (targetIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(targetIndex!);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load chapter: $e';
        _isLoading = false;
      });
    }
  }

  void _showBookSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Book'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allBooks.length,
              itemBuilder: (context, index) {
                final book = _allBooks[index];
                final isSelected = book.english == _currentBook?.english;
                return ListTile(
                  selected: isSelected,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.book,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    book.tamil,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(book.english),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentBook = book;
                      _currentChapter = 1;
                    });
                    _loadChapterData();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showChapterSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Chapter'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: _totalChapters,
              itemBuilder: (context, index) {
                final chapter = index + 1;
                final isSelected = chapter == _currentChapter;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentChapter = chapter;
                    });
                    _loadChapterData();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$chapter',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _selectVerse(int index) {
    setState(() {
      _selectedVerseIndex = index;
    });

    final verse = _verses[index];
    _saveToHistory(verse);
    _scrollToIndex(index);

    // Broadcast selected verse via server
    if (widget.serverService != null && widget.serverService!.isRunning) {
      final verseText = verse.verseText;
      widget.serverService!.sendMessage(verseText, 'bible', {
        'book': '${_currentBook?.tamil} $_currentChapter:${verse.verseNumber}',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📡 Verse broadcasted to all devices'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadHistory() async {
    final rows = await DatabaseHelper.instance.getBibleHistory();
    if (mounted) {
      setState(() {
        _verseHistory = rows;
      });
    }
  }

  Future<void> _saveToHistory(BibleVerse verse) async {
    if (_currentBook == null) return;
    await DatabaseHelper.instance.insertBibleHistory(
      bookEnglish: _currentBook!.english,
      bookTamil: _currentBook!.tamil,
      chapter: _currentChapter,
      verseNumber: verse.verseNumber,
    );
    await _loadHistory();
  }

  Future<void> _scrollToIndex(int index, {int retryCount = 0}) async {
    if (!mounted || index < 0 || index >= _verseKeys.length) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      _retryScrollToIndex(index, retryCount);
      return;
    }

    final ctx = _verseKeys[index].currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject == null) {
      _retryScrollToIndex(index, retryCount);
      return;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    final position = _scrollController.position;
    final revealOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final targetOffset = (revealOffset - 24).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    final delta = (position.pixels - targetOffset).abs();
    if (delta > 1) {
      await _scrollController.animateTo(
        targetOffset.toDouble(),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }

    if (_isVerseOutOfView(index) && retryCount < 6) {
      _retryScrollToIndex(index, retryCount);
    }
  }

  void _retryScrollToIndex(int index, int retryCount) {
    if (retryCount >= 6) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(index, retryCount: retryCount + 1);
    });
  }

  bool _isVerseOutOfView(int index) {
    if (!_scrollController.hasClients ||
        index < 0 ||
        index >= _verseKeys.length) {
      return false;
    }

    final ctx = _verseKeys[index].currentContext;
    final renderObject = ctx?.findRenderObject();
    if (renderObject == null) return false;

    final viewport = RenderAbstractViewport.of(renderObject);
    final position = _scrollController.position;
    final topOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final bottomOffset = viewport.getOffsetToReveal(renderObject, 1).offset;
    final visibleTop = position.pixels;
    final visibleBottom = position.pixels + position.viewportDimension;

    return topOffset < visibleTop || bottomOffset > visibleBottom;
  }

  void _showVerseSelector() {
    if (_verses.isEmpty) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Verse'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: _verses.length,
              itemBuilder: (context, index) {
                final verseNum = _verses[index].verseNumber;
                final isSelected = index == _selectedVerseIndex;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _selectVerse(index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$verseNum',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showHistoryDialog() {
    if (_verseHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verse history yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Group by day (most recent first)
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final entry in _verseHistory.reversed) {
      final dt = DateTime.parse(entry['timestamp'] as String).toLocal();
      final dayKey =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final days = grouped.keys.toList();
        return AlertDialog(
          title: const Text('Verse History'),
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
                        day,
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        onTap: () {
                          Navigator.pop(context);
                          _navigateToHistoryEntry(entry);
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
                await _loadHistory();
              },
              child: Text(
                'Clear All',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
  }

  void _navigateToHistoryEntry(Map<String, dynamic> entry) {
    final bookEnglish = entry['bookEnglish'] as String;
    final bookTamil = entry['bookTamil'] as String;
    final chapter = entry['chapter'] as int;
    final verseNumber = entry['verseNumber'] as int;
    final book = _allBooks.firstWhere(
      (b) => b.english == bookEnglish,
      orElse: () => BibleBook(english: bookEnglish, tamil: bookTamil),
    );
    setState(() {
      _currentBook = book;
      _currentChapter = chapter;
    });
    _loadChapterData(jumpToVerseNumber: verseNumber);
  }

  void _nextVerse() {
    if (_selectedVerseIndex == null) {
      _selectVerse(0);
    } else if (_selectedVerseIndex! < _verses.length - 1) {
      _selectVerse(_selectedVerseIndex! + 1);
    }
  }

  void _previousVerse() {
    if (_selectedVerseIndex == null) {
      _selectVerse(0);
    } else if (_selectedVerseIndex! > 0) {
      _selectVerse(_selectedVerseIndex! - 1);
    }
  }

  void _clearBroadcast() {
    setState(() {
      _selectedVerseIndex = null;
    });

    // Send empty message to clear the display
    if (widget.serverService != null && widget.serverService!.isRunning) {
      widget.serverService!.sendMessage('', 'bible', {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔲 Display cleared'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverActive =
        widget.serverService != null && widget.serverService!.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Book selector
            Flexible(
              child: InkWell(
                onTap: _showBookSelector,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _currentBook?.tamil ?? 'Loading...',
                        style: const TextStyle(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Chapter selector
            InkWell(
              onTap: _showChapterSelector,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentChapter',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 24),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Verse selector
            if (_verses.isNotEmpty)
              InkWell(
                onTap: _showVerseSelector,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedVerseIndex != null
                          ? 'v${_verses[_selectedVerseIndex!].verseNumber}'
                          : 'v-',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 24),
                  ],
                ),
              ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Verse History',
            onPressed: _showHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Presenter Settings',
            onPressed: () =>
                showPresenterSettingsDialog(context, globalPresenterConfig),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadChapterData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _verses.isEmpty
          ? Center(
              child: Text(
                'No verses found',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : Column(
              children: [
                if (serverActive)
                  const BroadcastInfoBanner(
                    message: 'Tap any verse to broadcast to connected devices',
                  ),
                if (serverActive)
                  BroadcastControlBar(
                    onPrevious: _previousVerse,
                    onNext: _nextVerse,
                    onClear: _clearBroadcast,
                    hasPrevious:
                        _selectedVerseIndex != null && _selectedVerseIndex! > 0,
                    hasNext:
                        _selectedVerseIndex != null &&
                        _selectedVerseIndex! < _verses.length - 1,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: List.generate(_verses.length, (index) {
                          final verse = _verses[index];
                          final isSelected = _selectedVerseIndex == index;
                          return GestureDetector(
                            key: _verseKeys[index],
                            onTap: () => _selectVerse(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                  width: isSelected ? 3 : 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${verse.verseNumber}. ${verse.verseText}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.6,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
