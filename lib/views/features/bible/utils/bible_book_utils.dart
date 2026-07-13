import '../../../../db/models/bible_book.dart';

/// Resolves the [BibleBook] a history/index entry refers to by matching on
/// its English name, falling back to a book constructed from the entry's
/// own English/Tamil names if it's no longer present in [books] (e.g. the
/// Bible data changed).
BibleBook resolveBookFromHistory(
  List<BibleBook> books, {
  required String bookEnglish,
  required String bookTamil,
}) {
  return books.firstWhere(
    (b) => b.english == bookEnglish,
    orElse: () => BibleBook(english: bookEnglish, tamil: bookTamil),
  );
}

/// Returns the subset of [books] whose Tamil or English name contains
/// [query] (case-insensitive). Returns [books] unchanged when [query] is
/// blank.
List<BibleBook> filterBooksByQuery(List<BibleBook> books, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return books;
  return books
      .where(
        (book) =>
            book.english.toLowerCase().contains(normalized) ||
            book.tamil.toLowerCase().contains(normalized),
      )
      .toList();
}
