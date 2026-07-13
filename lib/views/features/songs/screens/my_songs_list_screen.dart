import 'package:flutter/material.dart';
import '../../../../db/database_helper.dart';
import '../../../../db/models/song_list.dart';
import '../utils/confirm_delete_dialog.dart';
import '../utils/list_name_sheet.dart';
import '../widgets/compact_action_button.dart';
import 'view_list_songs_screen.dart';

class MySongsListScreen extends StatefulWidget {
  const MySongsListScreen({super.key});

  @override
  State<MySongsListScreen> createState() => _MySongsListScreenState();
}

class _MySongsListScreenState extends State<MySongsListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<SongList> _lists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    final lists = await _db.readAllSongLists();
    setState(() {
      _lists = lists;
      _isLoading = false;
    });
  }

  Future<void> _createList() async {
    final result = await showListNameSheet(
      context,
      title: 'New List',
      confirmLabel: 'Create',
    );

    if (result != null && result.isNotEmpty) {
      await _db.createSongList(SongList(name: result));
      _loadLists();
    }
  }

  Future<void> _renameList(SongList list) async {
    if (list.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot rename default list')),
      );
      return;
    }

    final result = await showListNameSheet(
      context,
      title: 'Rename List',
      confirmLabel: 'Rename',
      initialValue: list.name,
    );

    if (result != null && result.isNotEmpty && result != list.name) {
      await _db.updateSongList(
        SongList(id: list.id, name: result, createdAt: list.createdAt),
      );
      _loadLists();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$result"')));
      }
    }
  }

  Future<void> _deleteList(SongList list) async {
    if (list.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default list')),
      );
      return;
    }

    final confirmed = await confirmDelete(
      context,
      title: 'Delete List',
      message: 'Are you sure you want to delete "${list.name}"?',
    );

    if (confirmed) {
      await _db.deleteSongList(list.id!);
      _loadLists();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${list.name} deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Songs List'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createList,
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lists.length,
              itemBuilder: (context, index) {
                final list = _lists[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      list.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: list.isDefault
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CompactActionButton(
                                icon: Icons.edit,
                                color: Colors.blue,
                                tooltip: 'Rename list',
                                onPressed: () => _renameList(list),
                              ),
                              CompactActionButton(
                                icon: Icons.delete,
                                color: Colors.red,
                                tooltip: 'Delete list',
                                onPressed: () => _deleteList(list),
                              ),
                            ],
                          ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewListSongsScreen(songList: list),
                        ),
                      );
                      _loadLists();
                    },
                  ),
                );
              },
            ),
    );
  }
}
