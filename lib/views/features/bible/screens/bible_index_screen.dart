import 'package:church_presenter/main.dart';
import 'package:flutter/material.dart';
import '../../../../services/bible_service.dart';
import '../../../../services/server_service.dart';
import '../../../../db/models/bible_book.dart';
import '../../../widgets/presenter_settings_panel.dart';
import '../../../widgets/search_input_decoration.dart';
import '../utils/bible_book_utils.dart';
import '../widgets/bible_verse_history_button.dart';
import 'bible_view_book_screen.dart';

class BibleIndexScreen extends StatefulWidget {
  final ServerService? serverService;

  const BibleIndexScreen({super.key, this.serverService});

  @override
  State<BibleIndexScreen> createState() => _BibleIndexScreenState();
}

class _BibleIndexScreenState extends State<BibleIndexScreen> {
  final BibleService _bibleService = BibleService();
  final TextEditingController _searchController = TextEditingController();
  List<BibleBook> _books = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  List<BibleBook> get _filteredBooks =>
      filterBooksByQuery(_books, _searchQuery);

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final books = await _bibleService.loadBooks();

      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load books: $e';
        _isLoading = false;
      });
    }
  }

  void _openBook(
    BibleBook book, {
    int initialChapter = 1,
    int? initialVerseNumber,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BibleViewBookScreen(
          book: book,
          bibleService: _bibleService,
          serverService: widget.serverService,
          initialChapter: initialChapter,
          initialVerseNumber: initialVerseNumber,
        ),
      ),
    );
  }

  void _openHistoryEntry(Map<String, dynamic> entry) {
    final chapter = entry['chapter'] as int;
    final verseNumber = entry['verseNumber'] as int;
    final book = resolveBookFromHistory(
      _books,
      bookEnglish: entry['bookEnglish'] as String,
      bookTamil: entry['bookTamil'] as String,
    );

    _openBook(book, initialChapter: chapter, initialVerseNumber: verseNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible'),
        elevation: 0,
        actions: [
          BibleVerseHistoryButton(onEntrySelected: _openHistoryEntry),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Presenter Settings',
            onPressed: () =>
                showPresenterSettingsDialog(context, globalPresenterConfig),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: searchInputDecoration(
                hintText: 'Search books',
                hasValue: _searchQuery.isNotEmpty,
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
          ),
        ),
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
                    onPressed: _loadBooks,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _filteredBooks.isEmpty
          ? Center(
              child: Text(
                'No books match "$_searchQuery"',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              itemCount: _filteredBooks.length,
              itemBuilder: (context, index) {
                final book = _filteredBooks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(
                      book.tamil,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      book.english,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () => _openBook(book),
                  ),
                );
              },
            ),
    );
  }
}
