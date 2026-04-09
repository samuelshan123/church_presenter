import 'package:flutter/material.dart';
import '../../../db/models/song.dart';
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
