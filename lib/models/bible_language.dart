/// Which bundled Bible translation is shown on the controller and broadcast
/// to displays. Both share the same book/chapter/verse numbering, so
/// switching keeps the reader on the same verse.
enum BibleLanguage {
  /// Tamil Bible (`assets/bible/<Book>.json`).
  tamil('தமிழ்'),

  /// King James Version (`assets/bible/en/<Book>.json`).
  english('EN');

  const BibleLanguage(this.shortLabel);

  /// Label for the quick-switch toggle.
  final String shortLabel;
}
