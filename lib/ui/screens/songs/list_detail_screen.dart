import 'package:flutter/material.dart';
import '../../../db/database_helper.dart';
import '../../../db/models/song.dart';
import '../../../db/models/song_list.dart';
import '../../../main.dart';
import 'add_edit_song_screen.dart';
import 'song_detail_screen.dart';

class ListDetailScreen extends StatefulWidget {
  final SongList songList;

  const ListDetailScreen({super.key, required this.songList});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Permanently delete "${song.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
            icon:  const Icon(Icons.add),
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
                    ).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No songs in this list',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + icon to add songs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
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
                          builder: (context) => SongDetailScreen(
                            song: song,
                            serverService: globalServerService,
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // subtitle: Text(
                      //   song.content.length > 50
                      //       ? '${song.content.substring(0, 50)}...'
                      //       : song.content,
                      //   maxLines: 2,
                      //   overflow: TextOverflow.ellipsis,
                      // ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            color: Colors.blue,
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
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
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
