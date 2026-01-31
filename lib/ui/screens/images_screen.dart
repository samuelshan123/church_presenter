import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/image_service.dart';
import '../../services/server_service.dart';

class ImagesScreen extends StatelessWidget {
  final ServerService serverService;

  const ImagesScreen({super.key, required this.serverService});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && context.mounted) {
      final imageService = context.read<ImageService>();
      final result = await imageService.addImage(File(image.path));

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image added to gallery')));
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add image')));
      }
    }
  }

  void _presentImage(BuildContext context, String imagePath) {
    final imageService = context.read<ImageService>();
    imageService.setCurrentImage(imagePath);
    serverService.sendMessage('', 'image', {'imagePath': imagePath});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Presenting image')));
  }

  void _clearPresentation(BuildContext context) {
    final imageService = context.read<ImageService>();
    imageService.clearCurrentImage();
    serverService.sendMessage('Welcome', 'text', null);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Presentation cleared')));
  }

  Future<void> _deleteImage(BuildContext context, String imagePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Image'),
        content: const Text('Are you sure you want to remove this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final imageService = context.read<ImageService>();
      await imageService.deleteImage(imagePath);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        elevation: 0,
        actions: [
          Consumer<ImageService>(
            builder: (context, imageService, child) {
              if (imageService.hasCurrentImage) {
                return IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear presentation',
                  onPressed: () => _clearPresentation(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<ImageService>(
        builder: (context, imageService, child) {
          if (imageService.images.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add images to present',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _pickImage(context),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Image'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _pickImage(context),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Image'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (imageService.hasCurrentImage) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.settings,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Display Settings',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Display Mode',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: ImageDisplayMode.values.map((mode) {
                                  final isSelected =
                                      imageService.displayMode == mode;
                                  return ChoiceChip(
                                    label: Text(mode.label),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        imageService.setDisplayMode(mode);
                                        // Re-send the current image with new settings
                                        if (imageService.currentImagePath !=
                                            null) {
                                          serverService.sendMessage(
                                            '',
                                            'image',
                                            {
                                              'imagePath':
                                                  imageService.currentImagePath,
                                            },
                                          );
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Zoom Level: ${(imageService.zoomLevel * 100).toInt()}%',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton.filled(
                                    onPressed: () {
                                      imageService.zoomOut();
                                      if (imageService.currentImagePath !=
                                          null) {
                                        serverService.sendMessage('', 'image', {
                                          'imagePath':
                                              imageService.currentImagePath,
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.zoom_out),
                                    tooltip: 'Zoom Out',
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Slider(
                                      value: imageService.zoomLevel,
                                      min: 0.5,
                                      max: 3.0,
                                      divisions: 25,
                                      label:
                                          '${(imageService.zoomLevel * 100).toInt()}%',
                                      onChanged: (value) {
                                        imageService.setZoomLevel(value);
                                      },
                                      onChangeEnd: (value) {
                                        if (imageService.currentImagePath !=
                                            null) {
                                          serverService.sendMessage(
                                            '',
                                            'image',
                                            {
                                              'imagePath':
                                                  imageService.currentImagePath,
                                            },
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: () {
                                      imageService.zoomIn();
                                      if (imageService.currentImagePath !=
                                          null) {
                                        serverService.sendMessage('', 'image', {
                                          'imagePath':
                                              imageService.currentImagePath,
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.zoom_in),
                                    tooltip: 'Zoom In',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    onPressed: () {
                                      imageService.resetZoom();
                                      if (imageService.currentImagePath !=
                                          null) {
                                        serverService.sendMessage('', 'image', {
                                          'imagePath':
                                              imageService.currentImagePath,
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Reset Zoom',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => _clearPresentation(context),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Current Presentation'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: imageService.images.length,
                  itemBuilder: (context, index) {
                    final imagePath = imageService.images[index];
                    final isCurrentlyPresenting =
                        imageService.currentImagePath == imagePath;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: isCurrentlyPresenting ? 8 : 2,
                      color: isCurrentlyPresenting
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: Stack(
                        children: [
                          InkWell(
                            onTap: () => _presentImage(context, imagePath),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (isCurrentlyPresenting)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_arrow,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Presenting',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filled(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _deleteImage(context, imagePath),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
