import 'dart:convert';
import 'package:flutter/services.dart';
import '../db/models/bible_book.dart';
import '../db/models/bible_verse.dart';
import '../models/bible_language.dart';

class BibleService {
  static List<BibleBook>? _books;
  static final Map<String, Map<String, dynamic>> _booksCache = {};

  // Load books from JSON
  Future<List<BibleBook>> loadBooks() async {
    if (_books != null) return _books!;

    final jsonString = await rootBundle.loadString('assets/bible/Books.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    _books = jsonList.map((json) => BibleBook.fromJson(json)).toList();
    return _books!;
  }

  // Each translation is its own folder of per-book files with an identical
  // layout, so only the asset path differs.
  static String _assetPath(String bookName, BibleLanguage language) =>
      switch (language) {
        BibleLanguage.tamil => 'assets/bible/$bookName.json',
        BibleLanguage.english => 'assets/bible/en/$bookName.json',
      };

  // Load book data from JSON file
  Future<Map<String, dynamic>> _loadBookData(
    String bookName, [
    BibleLanguage language = BibleLanguage.tamil,
  ]) async {
    final cacheKey = '${language.name}/$bookName';
    if (_booksCache.containsKey(cacheKey)) {
      return _booksCache[cacheKey]!;
    }

    try {
      final jsonString = await rootBundle.loadString(
        _assetPath(bookName, language),
      );
      final bookData = json.decode(jsonString) as Map<String, dynamic>;
      _booksCache[cacheKey] = bookData;
      return bookData;
    } catch (e) {
      throw Exception('Failed to load book data for $bookName: $e');
    }
  }

  // Get verses for a specific book and chapter
  Future<List<BibleVerse>> getVerses(
    String bookName,
    int chapter, {
    BibleLanguage language = BibleLanguage.tamil,
  }) async {
    final bookData = await _loadBookData(bookName, language);
    final chapters = bookData['chapters'] as List<dynamic>;

    // Find the chapter (chapters are 1-indexed in JSON)
    final chapterData = chapters.firstWhere(
      (ch) => ch['chapter'] == chapter.toString(),
      orElse: () => null,
    );

    if (chapterData == null) {
      return [];
    }

    final verses = chapterData['verses'] as List<dynamic>;
    return verses.map((verseJson) {
      return BibleVerse(
        bookName: bookName,
        chapter: chapter,
        verseNumber: int.parse(verseJson['verse']),
        verseText: verseJson['text'],
      );
    }).toList();
  }

  // Get total chapters for a book. Both translations have identical chapter
  // counts (verified when the English files were generated), so the Tamil
  // file is the single source.
  Future<int> getChapterCount(String bookName) async {
    final bookData = await _loadBookData(bookName);
    final count = bookData['count'];

    if (count != null) {
      return int.parse(count.toString());
    }

    // Fallback: count chapters array length
    final chapters = bookData['chapters'] as List<dynamic>?;
    return chapters?.length ?? 1;
  }

  // Check if verses exist for a book
  Future<bool> hasVerses(String bookName) async {
    try {
      final bookData = await _loadBookData(bookName);
      final chapters = bookData['chapters'] as List<dynamic>?;
      return chapters != null && chapters.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Clear cache (useful for testing or memory management)
  void clearCache() {
    _booksCache.clear();
  }
}
