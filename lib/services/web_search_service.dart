import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;

class WebSongResult {
  final String title;
  final String source;
  final String resolvedSource;
  final String lyrics;

  const WebSongResult({
    required this.title,
    required this.source,
    required this.resolvedSource,
    required this.lyrics,
  });
}

class WebSearchService {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  Future<List<WebSongResult>> searchSongs(String query) async {
    final searchResults = await _searchWeb(query);

    final futures = searchResults.map((item) async {
      final realUrl = _extractRealUrl(item['url']!);
      if (realUrl == null) return null;

      final lyrics = await _scrapeLyrics(realUrl);
      if (!_isValidLyrics(lyrics)) return null;

      return WebSongResult(
        title: item['title']!,
        source: item['url']!,
        resolvedSource: realUrl,
        lyrics: lyrics,
      );
    });

    final rawResults = await Future.wait(futures);

    // Remove nulls and dedupe by normalised title (keep first occurrence)
    final seen = <String>{};
    final results = <WebSongResult>[];
    for (final item in rawResults) {
      if (item == null) continue;
      final key = _normalizeTitle(item.title);
      if (seen.add(key)) results.add(item);
    }

    return results;
  }

  // ── private helpers ────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> _searchWeb(String query) async {
    final uri = Uri.parse(
      'https://duckduckgo.com/html/?q=${Uri.encodeComponent('$query tamil christian song lyrics')}',
    );

    try {
      final response = await http
          .get(uri, headers: _defaultHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final document = htmlParser.parse(response.body);
      final resultLinks = document.querySelectorAll('.result__a');

      final results = <Map<String, String>>[];
      for (final el in resultLinks) {
        final title = el.text.trim();
        final link = el.attributes['href'];
        if (title.isNotEmpty && link != null && link.isNotEmpty) {
          results.add({'title': title, 'url': link});
        }
      }

      return results.take(10).toList();
    } catch (_) {
      return [];
    }
  }

  String? _extractRealUrl(String duckUrl) {
    try {
      final normalized =
          duckUrl.startsWith('//') ? 'https:$duckUrl' : duckUrl;
      final parsed = Uri.parse(normalized);
      final uddg = parsed.queryParameters['uddg'];
      if (uddg != null && uddg.isNotEmpty) return Uri.decodeComponent(uddg);
      return normalized;
    } catch (_) {
      return null;
    }
  }

  Future<String> _scrapeLyrics(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _defaultHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return '';

      final document = htmlParser.parse(response.body);

      const selectors = [
        '#tamiltext',
        '.entry-content',
        '.post-content',
        '.td-post-content',
        '.lyrics',
        '#lyrics',
        'article',
        '.single-post',
        '.content',
      ];

      for (final selector in selectors) {
        final container = document.querySelector(selector);
        if (container == null) continue;

        // Strip noise elements
        container
            .querySelectorAll('script, style, noscript, iframe, nav, footer, header')
            .forEach((e) => e.remove());

        // Convert <br> to newlines before text extraction
        var html = container.innerHtml;
        html =
            html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

        final text =
            htmlParser.parse(html).body?.text.trim() ?? '';
        if (text.length > 50) return _cleanLyrics(text);
      }

      // Fallback: collect <p> text blocks
      final parts = <String>[];
      document.querySelectorAll('p').forEach((el) {
        final t = el.text.trim();
        if (t.length > 10) parts.add(t);
      });
      return _cleanLyrics(parts.join('\n'));
    } catch (_) {
      return '';
    }
  }

  String _normalizeSpaces(String text) {
    return text
        .replaceAll('\r', '')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _cleanLyrics(String lyrics) {
    if (lyrics.isEmpty) return '';
    var cleaned = _normalizeSpaces(lyrics);

    const stopWords = [
      'lyrics in english',
      'powerpoint presentation',
      'ppt',
      'add to favorites',
      'song meaning',
      'key takeaways',
      'related songs',
      'keyboard chords',
      'generic selectors',
      'exact matches only',
      'search in title',
      'now its easy to search lyrics',
      'home » blog',
      'save saved removed',
      'download',
      'fullscreen button',
    ];

    final lower = cleaned.toLowerCase();
    var cutIndex = cleaned.length;
    for (final word in stopWords) {
      final idx = lower.indexOf(word);
      if (idx != -1 && idx < cutIndex) cutIndex = idx;
    }

    cleaned = cleaned.substring(0, cutIndex).trim();
    return _normalizeSpaces(cleaned);
  }

  bool _isValidLyrics(String text) {
    if (text.trim().length < 120) return false;
    final lower = text.toLowerCase();
    const badPatterns = [
      'key takeaways',
      'generic selectors',
      'search in title',
      'save saved removed',
    ];
    return !badPatterns.any((p) => lower.contains(p));
  }

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'lyrics', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'tamil christian songs', caseSensitive: false), '')
        .replaceAll(RegExp(r'christian song', caseSensitive: false), '')
        .replaceAll(RegExp(r'song lyrics', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z0-9\u0B80-\u0BFF]'), '')
        .trim();
  }
}
