import 'package:flutter/material.dart';
import '../../../db/database_helper.dart';
import '../../../db/models/song.dart';
import '../../../db/models/song_list.dart';
import '../../../main.dart';
import '../../../services/server_service.dart';
import '../../widgets/broadcast_info_banner.dart';
import '../../widgets/broadcast_control_bar.dart';
import '../../widgets/presenter_settings_panel.dart';

class ViewSongScreen extends StatefulWidget {
  final Song song;
  final ServerService? serverService;

  const ViewSongScreen({super.key, required this.song, this.serverService});

  @override
  State<ViewSongScreen> createState() => _ViewSongScreenState();
}

class _ViewSongScreenState extends State<ViewSongScreen> {
  int? _selectedSectionIndex;
  List<String> _sections = [];
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _parseSections();
  }

void _parseSections() {
  final content = widget.song.content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();

  // debugPrint(content);

  _sections = content
      .split(RegExp(r'\n\s*\n'))
      .where((section) => section.trim().isNotEmpty)
      .map((section) => section.trim())
      .toList();
}

  void _selectSection(int index) {
    setState(() {
      _selectedSectionIndex = index;
    });

    // Broadcast selected section via server
    if (widget.serverService != null && widget.serverService!.isRunning) {
      final selectedText = _sections[index];
      widget.serverService!.sendMessage(selectedText, 'song', {});

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
    } else if (_selectedSectionIndex! < _sections.length - 1) {
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
    setState(() {
      _selectedSectionIndex = null;
    });

    // Send empty message to clear the display
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

  Future<void> _showAddToListDialog() async {
    // If this is a synced/remote song (no local id), save it locally first
    Song song = widget.song;
    if (song.id == null) {
      song = await _db.createSong(song);
    }

    final lists = await _db.readAllSongLists();
    final membership = <int, bool>{};
    for (final list in lists) {
      membership[list.id!] = await _db.isSongInList(list.id!, song.id!);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => _AddToListDialog(
        songId: song.id!,
        lists: lists,
        initialMembership: membership,
        db: _db,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverActive =
        widget.serverService != null && widget.serverService!.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Add to List',
            onPressed: _showAddToListDialog,
          ),
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
              message: 'Tap any section to broadcast to connected devices',
            ),
          if (serverActive)
            BroadcastControlBar(
              onPrevious: _previousSection,
              onNext: _nextSection,
              onClear: _clearBroadcast,
              hasPrevious:
                  _selectedSectionIndex != null && _selectedSectionIndex! > 0,
              hasNext:
                  _selectedSectionIndex != null &&
                  _selectedSectionIndex! < _sections.length - 1,
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedSectionIndex == index;
                return GestureDetector(
                  onTap: () => _selectSection(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.2),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sections[index],
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.6,
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
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

class _AddToListDialog extends StatefulWidget {
  final int songId;
  final List<SongList> lists;
  final Map<int, bool> initialMembership;
  final DatabaseHelper db;

  const _AddToListDialog({
    required this.songId,
    required this.lists,
    required this.initialMembership,
    required this.db,
  });

  @override
  State<_AddToListDialog> createState() => _AddToListDialogState();
}

class _AddToListDialogState extends State<_AddToListDialog> {
  late List<SongList> _lists;
  late Map<int, bool> _membership;

  @override
  void initState() {
    super.initState();
    _lists = List.from(widget.lists);
    _membership = Map.from(widget.initialMembership);
  }

  Future<void> _toggleList(SongList list) async {
    final alreadyIn = _membership[list.id!] ?? false;
    if (alreadyIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Already in "${list.name}"'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final added = await widget.db.addSongToList(list.id!, widget.songId);
    if (added) {
      setState(() => _membership[list.id!] = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to "${list.name}"'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _createAndAddToList() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'List Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    final newList = await widget.db.createSongList(
      SongList(name: name.trim()),
    );
    await widget.db.addSongToList(newList.id!, widget.songId);

    setState(() {
      _lists.add(newList);
      _membership[newList.id!] = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created "${newList.name}" and added song'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to List'),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('No lists yet. Create one below.'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lists.length,
                itemBuilder: (context, index) {
                  final list = _lists[index];
                  final inList = _membership[list.id!] ?? false;
                  return ListTile(
                    leading: Icon(
                      list.name == 'Favorite Songs'
                          ? Icons.star
                          : Icons.playlist_play,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(list.name),
                    trailing: inList
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : const Icon(Icons.add_circle_outline),
                    onTap: () => _toggleList(list),
                  );
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Create New List'),
              onTap: _createAndAddToList,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
