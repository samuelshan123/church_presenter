import 'package:flutter/material.dart';
import '../../../../db/database_helper.dart';
import '../../../../db/models/song.dart';
import '../../../../db/models/song_list.dart';
import '../../../../main.dart';
import '../utils/confirm_delete_dialog.dart';
import '../widgets/compact_action_button.dart';
import 'add_edit_song_screen.dart';
import 'view_song_screen.dart';

class ViewListSongsScreen extends StatefulWidget {
  final SongList songList;

  const ViewListSongsScreen({super.key, required this.songList});

  @override
  State<ViewListSongsScreen> createState() => _ViewListSongsScreenState();
}

class _ViewListSongsScreenState extends State<ViewListSongsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Song> _songsInList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    final songsInList = await _db.getSongsInList(widget.songList.id!);
    setState(() {
      _songsInList = songsInList;
      _isLoading = false;
    });
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete Song',
      message: 'Permanently delete "${song.title}"?',
    );

    if (confirmed) {
      await _db.deleteSong(song.id!);
      _loadSongs();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${song.title} deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songList.name),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create New Song',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddEditSongScreen(addToListId: widget.songList.id),
                ),
              );
              _loadSongs();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songsInList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.playlist_add,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No songs in this list',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + icon to add songs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _songsInList.length,
              itemBuilder: (context, index) {
                final song = _songsInList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewSongScreen(
                            song: song,
                            serverService: globalServerService,
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text(
                        //index + 1 to show 1-based numbering
                        '${index + 1}. ${song.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CompactActionButton(
                            icon: Icons.edit,
                            color: Colors.blue,
                            tooltip: 'Edit song',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddEditSongScreen(song: song),
                                ),
                              );
                              _loadSongs();
                            },
                          ),
                          CompactActionButton(
                            icon: Icons.delete,
                            color: Colors.red,
                            tooltip: 'Delete song',
                            onPressed: () => _deleteSong(song),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
