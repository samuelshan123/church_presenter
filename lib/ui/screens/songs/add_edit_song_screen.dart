import 'package:flutter/material.dart';
import '../../../db/database_helper.dart';
import '../../../db/models/song.dart';

class AddEditSongScreen extends StatefulWidget {
  final Song? song;
  final int? addToListId; // List ID to auto-add the song to after creation

  const AddEditSongScreen({super.key, this.song, this.addToListId});

  @override
  State<AddEditSongScreen> createState() => _AddEditSongScreenState();
}

class _AddEditSongScreenState extends State<AddEditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.song != null) {
      _titleController.text = widget.song!.title;
      _contentController.text = widget.song!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.song == null) {
        // Create new song
        final newSong = Song(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        );
        final createdSong = await _db.createSong(newSong);

        // If listId provided, add song to that list
        if (widget.addToListId != null && createdSong.id != null) {
          await _db.addSongToList(widget.addToListId!, createdSong.id!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song created successfully')),
          );
        }
      } else {
        // Update existing song
        await _db.updateSong(
          widget.song!.copyWith(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song updated successfully')),
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.song != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Song' : 'Add Song'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Song Title',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                hintText: 'Enter song title',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.title),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Title is required';
                                }
                                return null;
                              },
                              textCapitalization: TextCapitalization.words,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Song Content',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contentController,
                              decoration: InputDecoration(
                                labelText: 'Content',
                                hintText: 'Enter song lyrics or content',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Content is required';
                                }
                                return null;
                              },
                              maxLines: 15,
                              minLines: 10,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSong,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'Update Song' : 'Add Song',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
