import 'package:flutter/material.dart';

import '../../../db/database_helper.dart';
import '../../../db/models/sync_song_detail.dart';

// ---------------------------------------------------------------------------
// Tamil character index
// ---------------------------------------------------------------------------

/// All Tamil consonant/vowel roots used as the browse index.
const List<String> kTamilAlphabet = [
  'அ', 'ஆ', 'இ', 'ஈ', 'உ', 'ஊ',
  'எ', 'ஏ', 'ஐ', 'ஒ', 'ஓ',
  'க', 'ச', 'ஜ', 'ஞ', 'ட', 'த',
  'ந', 'ப', 'ம', 'ய', 'ர',
  'ல', 'வ', 'ஷ', 'ஸ', 'ஸ்ரீ', 'ஹ',
];

// ---------------------------------------------------------------------------
// Browse-by-letter grid page
// ---------------------------------------------------------------------------

/// Displays a grid of Tamil characters. Tapping one navigates to
/// [_SongsByLetterPage] showing all synced songs whose titles begin with
/// that character.
class BrowseByLetterScreen extends StatelessWidget {
  const BrowseByLetterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse by Letter'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a Tamil letter to browse songs',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: kTamilAlphabet.length,
                itemBuilder: (context, index) {
                  final letter = kTamilAlphabet[index];
                  return _LetterTile(
                    letter: letter,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            _SongsByLetterPage(letter: letter),
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
// Songs list filtered by a single Tamil letter
// ---------------------------------------------------------------------------

class _SongsByLetterPage extends StatefulWidget {
  const _SongsByLetterPage({required this.letter});
  final String letter;

  @override
  State<_SongsByLetterPage> createState() => _SongsByLetterPageState();
}

class _SongsByLetterPageState extends State<_SongsByLetterPage> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  List<SyncSongDetail> _allSongs = [];
  List<SyncSongDetail> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    final songs =
        await _db.getSyncedSongsByFirstLetter(widget.letter);
    setState(() {
      _allSongs = songs;
      _filtered = songs;
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allSongs;
      } else {
        _filtered = _allSongs
            .where((s) =>
                s.title.toLowerCase().contains(q) ||
                s.lyrics.toLowerCase().contains(q))
            .toList();
      }
    });
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
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search within "${widget.letter}" songs…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                    },
                  ),
              ],
              elevation: WidgetStateProperty.all(1),
            ),
          ),

          // ── Result count ─────────────────────────────────────────────
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} song${_filtered.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          // ── Song list ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _EmptyState(letter: widget.letter)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final song = _filtered[index];
                          return _SongCard(
                            song: song,
                            searchQuery: _searchCtrl.text.trim(),
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
// Individual song card + detail view
// ---------------------------------------------------------------------------

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.searchQuery});
  final SyncSongDetail song;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          song.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: song.lyrics.isNotEmpty
            ? Text(
                song.lyrics.split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _SongDetailPage(song: song),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen song detail (lyrics)
// ---------------------------------------------------------------------------

class _SongDetailPage extends StatelessWidget {
  const _SongDetailPage({required this.song});
  final SyncSongDetail song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(song.title),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Song #${song.remoteId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            Text(
              song.lyrics.isEmpty ? '(No lyrics available)' : song.lyrics,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(height: 1.7, fontSize: 17),
            ),
          ],
        ),
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
          Icon(Icons.music_off_outlined,
              size: 72, color: cs.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            'No synced songs starting with "$letter"',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try syncing songs first from the Sync Songs page.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}
