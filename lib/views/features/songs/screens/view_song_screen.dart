import 'package:flutter/material.dart';
import '../../../../db/database_helper.dart';
import '../../../../db/models/song.dart';
import '../../../../db/models/song_list.dart';
import '../../../../main.dart';
import '../../../../services/server_service.dart';
import '../../../widgets/broadcast_info_banner.dart';
import '../../../widgets/broadcast_control_bar.dart';
import '../../../widgets/presenter_settings_panel.dart';
import '../utils/list_name_sheet.dart';
import '../utils/section_broadcast_controller.dart';
import '../utils/song_section_parser.dart';

class ViewSongScreen extends StatefulWidget {
  final Song song;
  final ServerService? serverService;

  const ViewSongScreen({super.key, required this.song, this.serverService});

  @override
  State<ViewSongScreen> createState() => _ViewSongScreenState();
}

class _ViewSongScreenState extends State<ViewSongScreen>
    with SectionBroadcastController<ViewSongScreen> {
  List<String> _sections = [];
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  ServerService? get serverService => widget.serverService;

  @override
  List<String> get sections => _sections;

  @override
  void dispose() {
    disposeSectionBroadcastListener();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sections = parseSongSections(widget.song.content);
    initSectionBroadcastListener();
  }

  Future<void> _showAddToListDialog() async {
    // If this is a synced/remote song (no local id), save it locally first
    Song song = widget.song;
    if (song.id == null) {
      song = await _db.createSong(song);
    }

    final lists = await _db.readAllSongLists();
    final memberListIds = await _db.getListIdsContainingSong(song.id!);
    final membership = {
      for (final list in lists) list.id!: memberListIds.contains(list.id!),
    };

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddToListSheet(
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
              onPrevious: previousSection,
              onNext: nextSection,
              onClear: clearBroadcast,
              hasPrevious: hasPreviousSection,
              hasNext: hasNextSection,
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final isSelected = selectedSectionIndex == index;
                return GestureDetector(
                  onTap: () => selectSection(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
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
                                fontWeight: FontWeight.w600,
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

class _AddToListSheet extends StatefulWidget {
  final int songId;
  final List<SongList> lists;
  final Map<int, bool> initialMembership;
  final DatabaseHelper db;

  const _AddToListSheet({
    required this.songId,
    required this.lists,
    required this.initialMembership,
    required this.db,
  });

  @override
  State<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<_AddToListSheet> {
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
    final name = await showListNameSheet(
      context,
      title: 'New List',
      confirmLabel: 'Create',
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
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to List',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _lists.isEmpty
                  ? const Center(
                      child: Text('No lists yet. Create one below.'),
                    )
                  : ListView.builder(
                      itemCount: _lists.length,
                      itemBuilder: (context, index) {
                        final list = _lists[index];
                        final inList = _membership[list.id!] ?? false;
                        return ListTile(
                          leading: Icon(
                            list.isDefault ? Icons.star : Icons.playlist_play,
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
    );
  }
}
