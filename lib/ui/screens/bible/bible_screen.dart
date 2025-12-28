import 'package:church_presenter/ui/screens/bible/bible_chapter_screen.dart';
import 'package:flutter/material.dart';
import '../../../services/bible_service.dart';
import '../../../services/server_service.dart';
import '../../../db/models/bible_book.dart';

class BibleScreen extends StatefulWidget {
  final ServerService? serverService;

  const BibleScreen({super.key, this.serverService});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
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

  void _openBook(BibleBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BibleChapterScreen(
          book: book,
          bibleService: _bibleService,
          serverService: widget.serverService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bible'), elevation: 0),
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
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                        ).colorScheme.onSurface.withOpacity(0.6),
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
