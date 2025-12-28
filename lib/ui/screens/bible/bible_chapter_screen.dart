import 'package:church_presenter/db/models/bible_book.dart';
import 'package:church_presenter/db/models/bible_verse.dart';
import 'package:church_presenter/services/bible_service.dart';
import 'package:church_presenter/services/server_service.dart';
import 'package:flutter/material.dart';
import '../../widgets/broadcast_info_banner.dart';
import '../../widgets/broadcast_control_bar.dart';

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
  bool _isLoading = true;
  String? _error;
  List<BibleBook> _allBooks = [];
  BibleBook? _currentBook;
  int? _selectedVerseIndex;

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _loadInitialData();
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

  Future<void> _loadChapterData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final totalChapters = await widget.bibleService.getChapterCount(
        _currentBook!.english,
      );
      final verses = await widget.bibleService.getVerses(
        _currentBook!.english,
        _currentChapter,
      );

      setState(() {
        _totalChapters = totalChapters;
        _verses = verses;
        _isLoading = false;
      });
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

    // Broadcast selected verse via server
    if (widget.serverService != null && widget.serverService!.isRunning) {
      final verse = _verses[index];
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
          ],
        ),
        elevation: 0,
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _verses.length,
                    itemBuilder: (context, index) {
                      final verse = _verses[index];
                      final isSelected = _selectedVerseIndex == index;
                      return GestureDetector(
                        onTap: serverActive ? () => _selectVerse(index) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: isSelected ? 3 : 1,
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
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
