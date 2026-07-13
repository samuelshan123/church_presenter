import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../../services/server_service.dart';

/// Shared song-section broadcast behavior: selecting a section sends it to
/// the [ServerService], next/previous move the selection, and clearing
/// blanks the display. Mix this into a [State] that exposes [serverService]
/// and the current [sections] list.
///
/// Call [initSectionBroadcastListener] from `initState` and
/// [disposeSectionBroadcastListener] from `dispose` so the currently
/// broadcast section is re-sent whenever presenter display settings change.
mixin SectionBroadcastController<T extends StatefulWidget> on State<T> {
  int? selectedSectionIndex;

  ServerService? get serverService;
  List<String> get sections;

  bool get _serverActive =>
      serverService != null && serverService!.isRunning;

  void initSectionBroadcastListener() {
    globalPresenterConfig.addListener(_onPresenterConfigChanged);
  }

  void disposeSectionBroadcastListener() {
    globalPresenterConfig.removeListener(_onPresenterConfigChanged);
  }

  void _onPresenterConfigChanged() {
    if (selectedSectionIndex != null && _serverActive) {
      serverService!.sendMessage(sections[selectedSectionIndex!], 'song', {});
    }
  }

  void selectSection(int index) {
    setState(() => selectedSectionIndex = index);
    if (_serverActive) {
      serverService!.sendMessage(sections[index], 'song', {});
    }
  }

  void nextSection() {
    if (selectedSectionIndex == null) {
      selectSection(0);
    } else if (selectedSectionIndex! < sections.length - 1) {
      selectSection(selectedSectionIndex! + 1);
    }
  }

  void previousSection() {
    if (selectedSectionIndex == null) {
      selectSection(0);
    } else if (selectedSectionIndex! > 0) {
      selectSection(selectedSectionIndex! - 1);
    }
  }

  void clearBroadcast() {
    setState(() => selectedSectionIndex = null);
    if (_serverActive) {
      serverService!.sendMessage('', 'song', {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔲 Display cleared'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  bool get hasPreviousSection =>
      selectedSectionIndex != null && selectedSectionIndex! > 0;

  bool get hasNextSection =>
      selectedSectionIndex != null &&
      selectedSectionIndex! < sections.length - 1;
}
