import '../../models/bible_language.dart';

class BibleBook {
  final String english;
  final String tamil;

  BibleBook({required this.english, required this.tamil});

  /// The book's name in [language] — e.g. for titles and verse references.
  String nameIn(BibleLanguage language) =>
      language == BibleLanguage.english ? english : tamil.trim();

  /// The book's name in the *other* language, shown as a secondary label.
  String otherNameThan(BibleLanguage language) =>
      language == BibleLanguage.english ? tamil.trim() : english;

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    final bookData = json['book'] as Map<String, dynamic>;
    return BibleBook(
      english: bookData['english'] as String,
      tamil: bookData['tamil'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': {'english': english, 'tamil': tamil},
    };
  }
}
