import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/bible_language.dart';
import '../../../../services/bible_language_service.dart';

/// Compact தமிழ் | EN switch for the Bible screens. It writes straight to
/// [BibleLanguageService]; screens listen to that service and reload, so
/// every Bible screen stays on the same language.
class BibleLanguageToggle extends StatelessWidget {
  const BibleLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<BibleLanguageService>();

    return SegmentedButton<BibleLanguage>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      segments: [
        for (final language in BibleLanguage.values)
          ButtonSegment(
            value: language,
            label: Text(language.shortLabel),
            tooltip: language == BibleLanguage.tamil
                ? 'Tamil'
                : 'English (KJV)',
          ),
      ],
      selected: {service.language},
      onSelectionChanged: (selection) => service.setLanguage(selection.first),
    );
  }
}
