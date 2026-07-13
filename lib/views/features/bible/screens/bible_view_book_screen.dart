import 'package:church_presenter/db/database_helper.dart';
import 'package:church_presenter/db/models/bible_book.dart';
import 'package:church_presenter/db/models/bible_verse.dart';
import 'package:church_presenter/main.dart';
import 'package:church_presenter/services/bible_service.dart';
import 'package:church_presenter/services/server_service.dart';
import 'package:church_presenter/views/features/bible/screens/bible_verse_image_editor_screen.dart';
import 'package:church_presenter/views/features/bible/widgets/bible_verse_history_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../widgets/broadcast_info_banner.dart';
import '../../../widgets/broadcast_control_bar.dart';
import '../../../widgets/presenter_settings_panel.dart';
import '../utils/bible_book_utils.dart';
import '../utils/selection_decoration.dart';
import '../widgets/grid_selector_dialog.dart';

class BibleViewBookScreen extends StatefulWidget {
  final BibleBook book;
  final BibleService bibleService;
  final ServerService? serverService;
  final int initialChapter;
  final int? initialVerseNumber;

  const BibleViewBookScreen({
    super.key,
    required this.book,
    required this.bibleService,
    this.serverService,
    this.initialChapter = 1,
    this.initialVerseNumber,
  });

  @override
  State<BibleViewBookScreen> createState() => _BibleViewBookScreenState();
}

class _BibleViewBookScreenState extends State<BibleViewBookScreen> {
  int _currentChapter = 1;
  int _totalChapters = 1;
  List<BibleVerse> _verses = [];
  List<GlobalKey> _verseKeys = [];
  bool _isLoading = true;
  String? _error;
  List<BibleBook> _allBooks = [];
  BibleBook? _currentBook;
  int? _selectedVerseIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    _currentChapter = widget.initialChapter;
    _loadInitialData();
    globalPresenterConfig.addListener(_onConfigChanged);
  }

  void _onConfigChanged() {
    if (_selectedVerseIndex != null &&
        widget.serverService != null &&
        widget.serverService!.isRunning) {
      final verse = _verses[_selectedVerseIndex!];
      widget.serverService!.sendMessage(verse.verseText, 'bible', {
        'book': '${_currentBook?.tamil} $_currentChapter:${verse.verseNumber}',
      });
    }
  }

  @override
  void dispose() {
    globalPresenterConfig.removeListener(_onConfigChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load all books for book selector
      _allBooks = await widget.bibleService.loadBooks();

      // Load chapter data
      await _loadChapterData(jumpToVerseNumber: widget.initialVerseNumber);
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return _BookSelectorSheet(
          allBooks: _allBooks,
          currentBook: _currentBook,
          onBookSelected: (book) {
            Navigator.pop(sheetContext);
            setState(() {
              _currentBook = book;
              _currentChapter = 1;
            });
            _loadChapterData();
          },
        );
      },
    );
  }

  void _showChapterSelector() {
    showGridSelectorDialog(
      context,
      title: 'Select Chapter',
      itemCount: _totalChapters,
      isSelectedIndex: (index) => index + 1 == _currentChapter,
      onSelectedIndex: (index) {
        setState(() {
          _currentChapter = index + 1;
        });
        _loadChapterData();
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

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('📡 Verse broadcasted to all devices'),
      //     duration: Duration(seconds: 1),
      //   ),
      // );
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
  }

  String _formatVerseForSharing(BibleVerse verse) {
    final reference =
        '${_currentBook?.tamil ?? _currentBook?.english ?? ''} $_currentChapter:${verse.verseNumber}';
    return '${verse.verseText}\n($reference)';
  }

  Future<void> _copyVerse(BibleVerse verse) async {
    await Clipboard.setData(ClipboardData(text: _formatVerseForSharing(verse)));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verse copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _shareVerseText(BibleVerse verse) async {
    final verseText = _formatVerseForSharing(verse);

    await SharePlus.instance.share(ShareParams(text: verseText));
  }

  Future<void> _shareVerseAsImage(BibleVerse verse) async {
    if (_currentBook == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BibleVerseImageEditorScreen(
          bookName: _currentBook!.tamil,
          chapter: _currentChapter,
          verseNumber: verse.verseNumber,
          verseText: verse.verseText,
        ),
      ),
    );
  }

  Future<void> _showVerseActions(BibleVerse verse) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.copy_rounded, color: colorScheme.primary),
                title: const Text('Copy'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _copyVerse(verse);
                },
              ),
              ListTile(
                leading: Icon(Icons.share_rounded, color: colorScheme.primary),
                title: const Text('Share as Text'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareVerseText(verse);
                },
              ),
              ListTile(
                leading: Icon(Icons.image_rounded, color: colorScheme.primary),
                title: const Text('Share as Image'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareVerseAsImage(verse);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Rough average height of a verse tile, used as the initial guess when
  // jumping to an off-screen target so the lazy ListView builds it. Refined
  // on each iteration using the actual position of already-built verses.
  static const double _estimatedVerseExtent = 90;

  Future<void> _scrollToIndex(int index) async {
    if (!mounted || index < 0 || index >= _verseKeys.length) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;

    // Iteratively jump closer to the target: each pass estimates the target
    // offset from the nearest verse that's actually been built (falling back
    // to a flat per-verse estimate the first time), until the exact verse
    // exists in the tree — then hand off to ensureVisible for the final,
    // precise alignment/animation.
    for (var i = 0; i < 8; i++) {
      final ctx = _verseKeys[index].currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
        return;
      }

      final estimatedOffset = _estimateOffsetForIndex(index);
      if (estimatedOffset == null) return;
      _scrollController.jumpTo(estimatedOffset);

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.hasClients) return;
    }
  }

  /// Estimates the scroll offset for [index] using the nearest verse whose
  /// render box is already known, falling back to a flat per-verse guess.
  double? _estimateOffsetForIndex(int index) {
    if (!_scrollController.hasClients) return null;
    final position = _scrollController.position;

    int? nearestBuiltIndex;
    double? nearestBuiltOffset;
    for (var i = 0; i < _verseKeys.length; i++) {
      final ctx = _verseKeys[i].currentContext;
      final renderObject = ctx?.findRenderObject();
      if (renderObject == null) continue;
      final viewport = RenderAbstractViewport.of(renderObject);
      final offset = viewport.getOffsetToReveal(renderObject, 0).offset;
      if (nearestBuiltIndex == null ||
          (i - index).abs() < (nearestBuiltIndex - index).abs()) {
        nearestBuiltIndex = i;
        nearestBuiltOffset = offset;
      }
    }

    final estimated = nearestBuiltIndex != null
        ? nearestBuiltOffset! +
              (index - nearestBuiltIndex) * _estimatedVerseExtent
        : index * _estimatedVerseExtent;

    return estimated.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  void _showVerseSelector() {
    if (_verses.isEmpty) return;
    showGridSelectorDialog(
      context,
      title: 'Select Verse',
      itemCount: _verses.length,
      labelForIndex: (index) => '${_verses[index].verseNumber}',
      isSelectedIndex: (index) => index == _selectedVerseIndex,
      onSelectedIndex: _selectVerse,
    );
  }

  void _navigateToHistoryEntry(Map<String, dynamic> entry) {
    final chapter = entry['chapter'] as int;
    final verseNumber = entry['verseNumber'] as int;
    final book = resolveBookFromHistory(
      _allBooks,
      bookEnglish: entry['bookEnglish'] as String,
      bookTamil: entry['bookTamil'] as String,
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

  Widget _buildTopSelector({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverActive =
        widget.serverService != null && widget.serverService!.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
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
          ],
        ),
        elevation: 0,
        actions: [
          BibleVerseHistoryButton(onEntrySelected: _navigateToHistoryEntry),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTopSelector(
                        label: 'Chapter',
                        value: '$_currentChapter',
                        onTap: _showChapterSelector,
                      ),
                      const SizedBox(width: 12),
                      _buildTopSelector(
                        label: 'Verse',
                        value: _selectedVerseIndex != null
                            ? '${_verses[_selectedVerseIndex!].verseNumber}'
                            : '-',
                        onTap: _showVerseSelector,
                      ),
                    ],
                  ),
                ),
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
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _verses.length,
                    itemBuilder: (context, index) {
                      final verse = _verses[index];
                      final isSelected = _selectedVerseIndex == index;
                      return GestureDetector(
                        key: _verseKeys[index],
                        onTap: () => _selectVerse(index),
                        onLongPress: () => _showVerseActions(verse),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: selectionBorder(
                              context,
                              isSelected: isSelected,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${verse.verseNumber}. ${verse.verseText}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    fontWeight: FontWeight.w600,
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

class _BookSelectorSheet extends StatefulWidget {
  final List<BibleBook> allBooks;
  final BibleBook? currentBook;
  final ValueChanged<BibleBook> onBookSelected;

  const _BookSelectorSheet({
    required this.allBooks,
    required this.currentBook,
    required this.onBookSelected,
  });

  @override
  State<_BookSelectorSheet> createState() => _BookSelectorSheetState();
}

class _BookSelectorSheetState extends State<_BookSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = filterBooksByQuery(widget.allBooks, _query);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Book',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search books (Tamil or English)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filteredBooks.isEmpty
                  ? Center(
                      child: Text(
                        'No books match "${_searchController.text}"',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredBooks.length,
                      itemBuilder: (context, index) {
                        final book = filteredBooks[index];
                        final isSelected =
                            book.english == widget.currentBook?.english;
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
                          onTap: () => widget.onBookSelected(book),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
