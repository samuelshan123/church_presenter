import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible_language.dart';

/// Remembers the Bible language chosen with the quick switch, so the app
/// reopens in the same translation.
class BibleLanguageService extends ChangeNotifier {
  static const String _languageKey = 'bible_language';

  BibleLanguage _language = BibleLanguage.tamil;

  BibleLanguage get language => _language;

  BibleLanguageService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    final language = BibleLanguage.values.firstWhere(
      (l) => l.name == stored,
      orElse: () => BibleLanguage.tamil,
    );
    if (language != _language) {
      _language = language;
      notifyListeners();
    }
  }

  Future<void> setLanguage(BibleLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.name);
  }
}
