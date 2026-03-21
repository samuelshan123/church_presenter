import 'package:flutter/material.dart';
import '../../../db/database_helper.dart';
import '../../../db/models/song.dart';
import '../../../db/models/song_list.dart';
import '../../../services/server_service.dart';
import '../../widgets/broadcast_info_banner.dart';
import '../../widgets/broadcast_control_bar.dart';

class WebSongDetailScreen extends StatefulWidget {
  final String title;
  final String lyrics;
  final String sourceUrl;
  final ServerService? serverService;

  const WebSongDetailScreen({
    super.key,
    required this.title,
    required this.lyrics,
    required this.sourceUrl,
    this.serverService,
  });

  @override
  State<WebSongDetailScreen> createState() => _WebSongDetailScreenState();
}

class _WebSongDetailScreenState extends State<WebSongDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late final TextEditingController _titleController;
  late final TextEditingController _lyricsController;

  int? _selectedSectionIndex;
  List<String> _displaySections = [];

  bool _checkingDb = true;
  bool _existsInDb = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _lyricsController = TextEditingController(text: widget.lyrics);
    _rebuildSections();
    _lyricsController.addListener(_rebuildSections);
    _checkLocalDb();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  // ── section parsing ────────────────────────────────────────────────────────

  void _rebuildSections() {
    final content = _lyricsController.text.trim();
    var sections = content
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();

    if (sections.length <= 1) {
      sections = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.trim())
          .toList();
    }

    final hasTamil = RegExp(r'[\u0B80-\u0BFF]').hasMatch(content);
    if (hasTamil) {
      final filtered = <String>[];
      for (final section in sections) {
        final lines = section.split('\n');
        final kept = lines
            .where((l) => !_isEnglishOnlyLine(l))
            .toList();
        final cleaned = kept.join('\n').trim();
        if (cleaned.isNotEmpty) filtered.add(cleaned);
      }
      setState(() => _displaySections = filtered);
    } else {
      setState(() => _displaySections = sections);
    }
  }

  bool _isEnglishOnlyLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[\x00-\x7F]+$').hasMatch(t);
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
      final created = await _db.createSong(song);
      if (listId != null && created.id != null) {
        await _db.addSongToList(listId, created.id!);
      }
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

  // ── broadcast helpers ──────────────────────────────────────────────────────

  void _selectSection(int index) {
    setState(() => _selectedSectionIndex = index);
    if (widget.serverService != null && widget.serverService!.isRunning) {
      widget.serverService!.sendMessage(_displaySections[index], 'song', {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📡 Section broadcasted to all devices'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _nextSection() {
    if (_selectedSectionIndex == null) {
      _selectSection(0);
    } else if (_selectedSectionIndex! < _displaySections.length - 1) {
      _selectSection(_selectedSectionIndex! + 1);
    }
  }

  void _previousSection() {
    if (_selectedSectionIndex == null) {
      _selectSection(0);
    } else if (_selectedSectionIndex! > 0) {
      _selectSection(_selectedSectionIndex! - 1);
    }
  }

  void _clearBroadcast() {
    setState(() => _selectedSectionIndex = null);
    if (widget.serverService != null && widget.serverService!.isRunning) {
      widget.serverService!.sendMessage('', 'song', {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔲 Display cleared'),
          duration: Duration(seconds: 1),
        ),
      );
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
      ),
      body: Column(
        children: [
          if (serverActive)
            const BroadcastInfoBanner(
              message: 'Tap any section below to broadcast to connected devices',
            ),
          if (serverActive)
            BroadcastControlBar(
              onPrevious: _previousSection,
              onNext: _nextSection,
              onClear: _clearBroadcast,
              hasPrevious:
                  _selectedSectionIndex != null && _selectedSectionIndex! > 0,
              hasNext: _selectedSectionIndex != null &&
                  _selectedSectionIndex! < _displaySections.length - 1,
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
                            textCapitalization: TextCapitalization.sentences,
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
                        final isSelected = _selectedSectionIndex == index;
                        return GestureDetector(
                          onTap: () => _selectSection(index),
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
