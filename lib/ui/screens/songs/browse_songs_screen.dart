import 'package:flutter/material.dart';

import '../../../db/database_helper.dart';
import '../../../db/models/song.dart';
import '../../../main.dart';
import 'view_song_screen.dart';

// ---------------------------------------------------------------------------
// Tamil letter index
// ---------------------------------------------------------------------------

const List<String> _kTamilAlphabet = [
  'அ', 'ஆ', 'இ', 'ஈ', 'உ', 'ஊ',
  'எ', 'ஏ', 'ஐ', 'ஒ', 'ஓ',
  'க', 'ச', 'ஜ', 'ஞ', 'ட', 'த',
  'ந', 'ப', 'ம', 'ய', 'ர',
  'ல', 'வ', 'ஷ', 'ஸ', 'ஸ்ரீ', 'ஹ',
];

// ---------------------------------------------------------------------------
// BrowseSongsScreen — Tamil alphabet grid index
// ---------------------------------------------------------------------------

/// Top-level entry for the synced Tamil song library.
/// Displays a 4-column grid of Tamil letters; tapping one opens [SongsByLetterScreen].
class BrowseSongsScreen extends StatelessWidget {
  const BrowseSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Songs'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a letter to browse Tamil songs',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemCount: _kTamilAlphabet.length,
                itemBuilder: (context, index) {
                  final letter = _kTamilAlphabet[index];
                  return _LetterTile(
                    letter: letter,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SongsByLetterScreen(letter: letter),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Letter tile
// ---------------------------------------------------------------------------

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, required this.onTap});
  final String letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Text(
            letter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SongsByLetterScreen — lightweight title-only list
// ---------------------------------------------------------------------------

/// Shows all synced songs whose title starts with [letter].
/// Only `remote_id` + `title` are loaded into the list — no lyrics.
/// Tapping a song fetches its full detail on demand, then opens [ViewSongScreen].
class SongsByLetterScreen extends StatefulWidget {
  const SongsByLetterScreen({super.key, required this.letter});
  final String letter;

  @override
  State<SongsByLetterScreen> createState() => _SongsByLetterScreenState();
}

class _SongsByLetterScreenState extends State<SongsByLetterScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  List<({String remoteId, String title})> _songs = [];
  bool _isLoading = true;
  String? _openingId; // tracks which row is being opened

  @override
  void initState() {
    super.initState();
    _loadTitles();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTitles({String? search}) async {
    setState(() => _isLoading = true);
    final rows = await _db.getSyncedSongTitlesByFirstLetter(
      widget.letter,
      search: (search == null || search.isEmpty) ? null : search,
    );
    if (mounted) {
      setState(() {
        _songs = rows;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _loadTitles(search: _searchCtrl.text.trim());
  }

  Future<void> _openSong(String remoteId, String title) async {
    if (_openingId != null) return;
    setState(() => _openingId = remoteId);
    try {
      final detail = await _db.getSyncedSongDetailById(remoteId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ViewSongScreen(
            song: Song(
              title: detail?.title ?? title,
              content: detail?.lyrics ?? '',
            ),
            serverService: globalServerService,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Songs — ${widget.letter}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search in "${widget.letter}" songs…',
              leading: const Icon(Icons.search, size: 20),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _searchCtrl.clear,
                  ),
              ],
              elevation: WidgetStateProperty.all(1),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),

          // Count
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isLoading
                    ? 'Loading…'
                    : '${_songs.length} song${_songs.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),

          // Song list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? _EmptyState(letter: widget.letter)
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: _songs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final s = _songs[index];
                          final isOpening = _openingId == s.remoteId;
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.1),
                                child: Text(
                                  s.title.isNotEmpty
                                      ? s.title[0]
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isOpening
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                              onTap: () =>
                                  _openSong(s.remoteId, s.title),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_off_outlined,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
          Text(
            'No songs found for "$letter"',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sync songs first from the Sync Songs page.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
          ),
        ],
      ),
    );
  }
}
