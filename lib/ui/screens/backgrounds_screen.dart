import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/background_service.dart';

class BackgroundsScreen extends StatelessWidget {
  const BackgroundsScreen({super.key});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && context.mounted) {
      final backgroundService = context.read<BackgroundService>();
      final result = await backgroundService.saveImage(File(image.path));

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background image selected')),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save image')));
      }
    }
  }

  Future<void> _clearImage(BuildContext context) async {
    final backgroundService = context.read<BackgroundService>();
    await backgroundService.clearImage();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Background image cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backgrounds'), elevation: 0),
      body: Consumer<BackgroundService>(
        builder: (context, backgroundService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Preview Section
                if (backgroundService.hasImage)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.file(
                            File(backgroundService.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Current Background',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _clearImage(context),
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No background selected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Select Image Button
                FilledButton.icon(
                  onPressed: () => _pickImage(context),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Select Background Image'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 32),

                // Display Type Section
                Text(
                  'Display Type',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ...DisplayType.values.map((type) {
                  final isSelected = backgroundService.displayType == type;
                  return Card(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      leading: Icon(
                        _getDisplayTypeIcon(type),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        type.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text(_getDisplayTypeDescription(type)),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => backgroundService.setDisplayType(type),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getDisplayTypeIcon(DisplayType type) {
    switch (type) {
      case DisplayType.fullscreen:
        return Icons.fullscreen;
      case DisplayType.portrait:
        return Icons.stay_current_portrait;
      case DisplayType.landscape:
        return Icons.stay_current_landscape;
    }
  }

  String _getDisplayTypeDescription(DisplayType type) {
    switch (type) {
      case DisplayType.fullscreen:
        return 'Fill entire screen, may crop';
      case DisplayType.portrait:
        return 'Optimize for portrait orientation';
      case DisplayType.landscape:
        return 'Optimize for landscape orientation';
    }
  }
}
