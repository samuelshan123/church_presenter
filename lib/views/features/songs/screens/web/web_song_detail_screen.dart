import 'package:flutter/material.dart';
import '../../../../../db/database_helper.dart';
import '../../../../../db/models/song.dart';
import '../../../../../db/models/song_list.dart';
import '../../../../../main.dart';
import '../../../../../services/server_service.dart';
import '../../../../../services/web_search_service.dart';
import '../../../../widgets/broadcast_info_banner.dart';
import '../../../../widgets/broadcast_control_bar.dart';
import '../../../../widgets/presenter_settings_panel.dart';
import '../../utils/section_broadcast_controller.dart';
import '../../utils/song_section_parser.dart';

class WebSongDetailScreen extends StatefulWidget {
  final String title;
  final String sourceUrl;
  final ServerService? serverService;

  const WebSongDetailScreen({
    super.key,
    required this.title,
    required this.sourceUrl,
    this.serverService,
  });

  @override
  State<WebSongDetailScreen> createState() => _WebSongDetailScreenState();
}

class _WebSongDetailScreenState extends State<WebSongDetailScreen>
    with SectionBroadcastController<WebSongDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _searchService = WebSearchService();
  late final TextEditingController _titleController;
  late final TextEditingController _lyricsController;

  List<String> _displaySections = [];

  bool _loadingLyrics = true;
  String? _lyricsError;

  bool _checkingDb = true;
  bool _existsInDb = false;
  bool _saving = false;

  @override
  ServerService? get serverService => widget.serverService;

  @override
  List<String> get sections => _displaySections;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _lyricsController = TextEditingController();
    _lyricsController.addListener(_rebuildSections);
    _checkLocalDb();
    _fetchLyrics();
    initSectionBroadcastListener();
  }

  @override
  void dispose() {
    disposeSectionBroadcastListener();
    _titleController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _loadingLyrics = true;
      _lyricsError = null;
    });
    try {
      final lyrics = await _searchService.fetchLyrics(widget.sourceUrl);
      if (!mounted) return;
      if (lyrics.isEmpty) {
        setState(() {
          _lyricsError = 'Could not extract lyrics from this page.';
          _loadingLyrics = false;
        });
      } else {
        _lyricsController.text = lyrics;
        setState(() => _loadingLyrics = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lyricsError = 'Failed to load lyrics. Check your connection.';
          _loadingLyrics = false;
        });
      }
    }
  }

  // ── section parsing ────────────────────────────────────────────────────────

  void _rebuildSections() {
    final content = _lyricsController.text.trim();
    final parsed = parseSongSections(content);
    setState(() {
      _displaySections = stripEnglishOnlyLinesIfTamil(parsed, content);
    });
  }

  // ── db helpers ─────────────────────────────────────────────────────────────

  Future<void> _checkLocalDb() async {
    final matches = await _db.searchSongsByTitle(widget.title);
    if (mounted) {
      setState(() {
        _existsInDb = matches.isNotEmpty;
        _checkingDb = false;
      });
    }
  }

  Future<void> _showSaveDialog() async {
    final lists = await _db.readAllSongLists();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SaveBottomSheet(
        lists: lists,
        onSave: (listId) async {
          Navigator.pop(ctx);
          await _performSave(listId);
        },
      ),
    );
  }

  Future<void> _performSave(int? listId) async {
    final title = _titleController.text.trim();
    final content = _lyricsController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and lyrics cannot be empty')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final song = Song(title: title, content: content);
      await _db.createSongAndOptionallyAddToList(song, listId);
      if (mounted) {
        setState(() {
          _saving = false;
          _existsInDb = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" saved'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final serverActive =
        widget.serverService != null && widget.serverService!.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Song'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Presenter Settings',
            onPressed: () => showPresenterSettingsDialog(
              context,
              globalPresenterConfig,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (serverActive)
            const BroadcastInfoBanner(
              message: 'Tap any section below to broadcast to connected devices',
            ),
          if (serverActive)
            BroadcastControlBar(
              onPrevious: previousSection,
              onNext: nextSection,
              onClear: clearBroadcast,
              hasPrevious: hasPreviousSection,
              hasNext: hasNextSection,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title field ──────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Song Title',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'Song title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.title),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Lyrics field ─────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lyrics',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_loadingLyrics)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text('Fetching lyrics…'),
                                  ],
                                ),
                              ),
                            )
                          else if (_lyricsError != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 40, color: Colors.orange),
                                  const SizedBox(height: 8),
                                  Text(
                                    _lyricsError!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _fetchLyrics,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          else
                            TextField(
                              controller: _lyricsController,
                              decoration: InputDecoration(
                                hintText: 'Song lyrics',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignLabelWithHint: true,
                              ),
                              maxLines: null,
                              minLines: 10,
                              textCapitalization:
                                  TextCapitalization.sentences,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Section preview ──────────────────────────────────────
                  if (_displaySections.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.view_list, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Preview  •  tap to broadcast',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.55),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _displaySections.length,
                      itemBuilder: (context, index) {
                        final isSelected = selectedSectionIndex == index;
                        return GestureDetector(
                          onTap: () => selectSection(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Text(
                              _displaySections[index],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    height: 1.6,
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (_checkingDb) return const SizedBox.shrink();

    if (_existsInDb) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context)
              .colorScheme
              .secondaryContainer
              .withOpacity(0.4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle,
                  size: 18,
                  color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Already saved in your library',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _showSaveDialog,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_alt),
            label: const Text('Save to Library'),
          ),
        ),
      ),
    );
  }
}

// ── Save destination bottom sheet ─────────────────────────────────────────────

class _SaveBottomSheet extends StatelessWidget {
  final List<SongList> lists;
  final void Function(int? listId) onSave;

  const _SaveBottomSheet({required this.lists, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Save to…',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // All Songs option
          _DestinationTile(
            icon: Icons.music_note,
            color: Colors.purple,
            title: 'All Songs',
            subtitle: 'Save to your main song library',
            onTap: () => onSave(null),
          ),
          if (lists.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'My Lists',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
            ),
            const SizedBox(height: 8),
            ...lists.map(
              (list) => _DestinationTile(
                icon: Icons.playlist_add,
                color: Colors.blue,
                title: list.name,
                subtitle: 'Save to this list',
                onTap: () => onSave(list.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DestinationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
