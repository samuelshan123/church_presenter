import 'package:church_presenter/main.dart';
import 'package:flutter/material.dart';
import '../../../../services/bible_service.dart';
import '../../../../services/server_service.dart';
import '../../../../db/models/bible_book.dart';
import '../../../widgets/presenter_settings_panel.dart';
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
  List<BibleBook> _books = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooks();
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
    final bookEnglish = entry['bookEnglish'] as String;
    final bookTamil = entry['bookTamil'] as String;
    final chapter = entry['chapter'] as int;
    final verseNumber = entry['verseNumber'] as int;
    final book = _books.firstWhere(
      (b) => b.english == bookEnglish,
      orElse: () => BibleBook(english: bookEnglish, tamil: bookTamil),
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
          : ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];
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
