import 'package:flutter/material.dart';
import '../../../db/database_helper.dart';
import '../../../db/models/song_list.dart';
import 'list_detail_screen.dart';

class MyListsScreen extends StatefulWidget {
  const MyListsScreen({super.key});

  @override
  State<MyListsScreen> createState() => _MyListsScreenState();
}

class _MyListsScreenState extends State<MyListsScreen> {
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
    final controller = TextEditingController();
    final result = await showDialog<String>(
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

    if (result != null && result.isNotEmpty) {
      await _db.createSongList(SongList(name: result));
      _loadLists();
    }
  }

  Future<void> _renameList(SongList list) async {
    if (list.name == 'Default List') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot rename default list')),
      );
      return;
    }

    final controller = TextEditingController(text: list.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'List Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
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
    if (list.name == 'Default List') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default list')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"?'),
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
      appBar: AppBar(title: const Text('My Lists'), elevation: 0),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        list.name == 'Default List'
                            ? Icons.star
                            : Icons.playlist_play,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      list.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: list.name != 'Default List'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                color: Colors.blue,
                                onPressed: () => _renameList(list),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red,
                                onPressed: () => _deleteList(list),
                              ),
                            ],
                          )
                        : null,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ListDetailScreen(songList: list),
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
