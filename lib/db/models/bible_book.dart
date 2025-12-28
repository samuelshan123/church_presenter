class BibleBook {
  final String english;
  final String tamil;

  BibleBook({
    required this.english,
    required this.tamil,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    final bookData = json['book'] as Map<String, dynamic>;
    return BibleBook(
      english: bookData['english'] as String,
      tamil: bookData['tamil'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': {
        'english': english,
        'tamil': tamil,
      }
    };
  }
}
