/// Splits song [content] into display sections: normalizes line endings,
/// splits on blank lines, and drops empty sections. Falls back to
/// splitting on single newlines when there's only one blank-line-delimited
/// section (e.g. content with no blank lines between verses).
List<String> parseSongSections(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();

  var sections = normalized
      .split(RegExp(r'\n\s*\n'))
      .where((s) => s.trim().isNotEmpty)
      .map((s) => s.trim())
      .toList();

  if (sections.length <= 1) {
    sections = normalized
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  return sections;
}

bool _isEnglishOnlyLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^[\x00-\x7F]+$').hasMatch(trimmed);
}

/// Removes English-only lines from each section when [content] contains
/// Tamil text — used for web-fetched lyrics that often interleave an
/// English transliteration with the original Tamil.
List<String> stripEnglishOnlyLinesIfTamil(
  List<String> sections,
  String content,
) {
  final hasTamil = RegExp(r'[஀-௿]').hasMatch(content);
  if (!hasTamil) return sections;

  final filtered = <String>[];
  for (final section in sections) {
    final kept = section
        .split('\n')
        .where((line) => !_isEnglishOnlyLine(line))
        .join('\n')
        .trim();
    if (kept.isNotEmpty) filtered.add(kept);
  }
  return filtered;
}
