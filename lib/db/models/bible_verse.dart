class BibleVerse {
  final String bookName;
  final int chapter;
  final int verseNumber;
  final String verseText;

  BibleVerse({
    required this.bookName,
    required this.chapter,
    required this.verseNumber,
    required this.verseText,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      bookName: json['bookName'] as String,
      chapter: json['chapter'] as int,
      verseNumber: json['verseNumber'] as int,
      verseText: json['verseText'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookName': bookName,
      'chapter': chapter,
      'verseNumber': verseNumber,
      'verseText': verseText,
    };
  }
}
