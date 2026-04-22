import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BibleVerseImageEditorScreen extends StatefulWidget {
  final String bookName;
  final int chapter;
  final int verseNumber;
  final String verseText;

  const BibleVerseImageEditorScreen({
    super.key,
    required this.bookName,
    required this.chapter,
    required this.verseNumber,
    required this.verseText,
  });

  @override
  State<BibleVerseImageEditorScreen> createState() =>
      _BibleVerseImageEditorScreenState();
}

enum _EditableLayer { verse, reference }

class _BibleVerseImageEditorScreenState
    extends State<BibleVerseImageEditorScreen> {
  static const Duration _selectionAnimationDuration = Duration(
    milliseconds: 160,
  );
  final GlobalKey _canvasKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _verseController = TextEditingController();

  late String _editedVerseText;
  _EditableLayer _selectedLayer = _EditableLayer.verse;

  int _selectedTemplateIndex = 0;
  Color _customBackgroundColor = const Color(0xFF0F172A);
  File? _backgroundImageFile;

  Color _verseTextColor = Colors.white;
  double _verseFontSize = 14;
  double _verseLineHeight = 1.35;
  double _verseWordSpacing = 1.2;
  TextAlign _verseTextAlign = TextAlign.center;
  Alignment _verseAlignment = const Alignment(0, 0.12);

  Color _referenceTextColor = const Color(0xFFF8FAFC);
  double _referenceFontSize = 12;
  double _referenceWordSpacing = 1.0;
  TextAlign _referenceTextAlign = TextAlign.center;

  bool _showSelectionOutline = true;
  bool _isSharing = false;

  static const List<_BackgroundTemplate> _templates = [
    _BackgroundTemplate(colors: [Color(0xFFFFC857), Color(0xFFE9724C)]),
    _BackgroundTemplate(colors: [Color(0xFF0F4C75), Color(0xFF3282B8)]),
    _BackgroundTemplate(colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)]),
    _BackgroundTemplate(colors: [Color(0xFF7F1D1D), Color(0xFFBE123C)]),
    _BackgroundTemplate(colors: [Color(0xFF111827), Color(0xFF312E81)]),
    _BackgroundTemplate(colors: [Color(0xFFE9C46A), Color(0xFFF4A261)]),
  ];

  static const List<Color> _textColorPresets = [
    Colors.white,
    Color(0xFFF8FAFC),
    Color(0xFFFACC15),
    Color(0xFFBFDBFE),
    Color(0xFFFBCFE8),
    Color(0xFFBBF7D0),
    Color(0xFFFFEDD5),
    Color(0xFF111827),
  ];

  String get _referenceText =>
      '${widget.bookName} ${widget.chapter}:${widget.verseNumber}';

  @override
  void initState() {
    super.initState();
    _editedVerseText = widget.verseText;
    _verseController.text = widget.verseText;
  }

  @override
  void dispose() {
    _verseController.dispose();
    super.dispose();
  }

  bool get _isEditingVerse => _selectedLayer == _EditableLayer.verse;

  Color get _activeTextColor =>
      _isEditingVerse ? _verseTextColor : _referenceTextColor;

  double get _activeFontSize =>
      _isEditingVerse ? _verseFontSize : _referenceFontSize;

  double get _activeWordSpacing =>
      _isEditingVerse ? _verseWordSpacing : _referenceWordSpacing;

  TextAlign get _activeTextAlign =>
      _isEditingVerse ? _verseTextAlign : _referenceTextAlign;

  Duration get _selectionFrameDuration =>
      _showSelectionOutline ? _selectionAnimationDuration : Duration.zero;

  Future<void> _pickBackgroundImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() {
      _backgroundImageFile = File(image.path);
    });
  }

  Future<void> _pickColor({
    required Color initialColor,
    required String title,
    required ValueChanged<Color> onSelected,
  }) async {
    Color currentColor = initialColor;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) => currentColor = color,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onSelected(currentColor);
                Navigator.pop(dialogContext);
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareCanvasAsImage() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
      _showSelectionOutline = false;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;

      final renderObject =
          _canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (renderObject == null) {
        throw StateError('Preview is not ready');
      }

      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode image');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/bible_verse_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: _referenceText),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share image: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _showSelectionOutline = true;
        });
      }
    }
  }

  void _updateActiveTextColor(Color color) {
    setState(() {
      if (_isEditingVerse) {
        _verseTextColor = color;
      } else {
        _referenceTextColor = color;
      }
    });
  }

  void _updateActiveFontSize(double value) {
    setState(() {
      if (_isEditingVerse) {
        _verseFontSize = value;
      } else {
        _referenceFontSize = value;
      }
    });
  }

  void _updateActiveWordSpacing(double value) {
    setState(() {
      if (_isEditingVerse) {
        _verseWordSpacing = value;
      } else {
        _referenceWordSpacing = value;
      }
    });
  }

  void _updateActiveTextAlign(TextAlign value) {
    setState(() {
      if (_isEditingVerse) {
        _verseTextAlign = value;
      } else {
        _referenceTextAlign = value;
      }
    });
  }

  void _resetVersePosition() {
    setState(() {
      _verseAlignment = const Alignment(0, 0.12);
    });
  }

  BoxDecoration _buildCanvasDecoration() {
    if (_backgroundImageFile != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: FileImage(_backgroundImageFile!),
          fit: BoxFit.cover,
        ),
      );
    }

    if (_selectedTemplateIndex < 0) {
      return BoxDecoration(color: _customBackgroundColor);
    }

    final template = _templates[_selectedTemplateIndex];
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [template.colors.first, template.colors.last],
      ),
    );
  }

  Widget _buildCanvasPreview() {
    return RepaintBoundary(
      key: _canvasKey,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: _buildCanvasDecoration(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_backgroundImageFile != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.16),
                        Colors.black.withValues(alpha: 0.36),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final verseWidth = constraints.maxWidth;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLayer = _EditableLayer.reference;
                              });
                            },
                            child: _SelectionFrame(
                              animationDuration: _selectionFrameDuration,
                              isSelected:
                                  _showSelectionOutline &&
                                  _selectedLayer == _EditableLayer.reference,
                              child: Text(
                                _referenceText,
                                textAlign: _referenceTextAlign,
                                style: TextStyle(
                                  color: _referenceTextColor,
                                  fontSize: _referenceFontSize,
                                  fontWeight: FontWeight.w700,
                                  wordSpacing: _referenceWordSpacing,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 2,
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: _verseAlignment,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLayer = _EditableLayer.verse;
                              });
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _selectedLayer = _EditableLayer.verse;
                                _verseAlignment = Alignment(
                                  (_verseAlignment.x + details.delta.dx / 140)
                                      .clamp(-0.92, 0.92),
                                  (_verseAlignment.y + details.delta.dy / 180)
                                      .clamp(-0.9, 0.9),
                                );
                              });
                            },
                            child: SizedBox(
                              width: verseWidth,
                              child: _buildVerseLayer(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerseLayer() {
    return _SelectionFrame(
      animationDuration: _selectionFrameDuration,
      expandToMaxWidth: true,
      isSelected:
          _showSelectionOutline && _selectedLayer == _EditableLayer.verse,
      child: Text(
        _editedVerseText,
        textAlign: _verseTextAlign,
        style: TextStyle(
          color: _verseTextColor,
          fontSize: _verseFontSize,
          height: _verseLineHeight,
          fontWeight: FontWeight.w700,
          wordSpacing: _verseWordSpacing,
          shadows: const [
            Shadow(
              blurRadius: 2.5,
              color: Colors.black54,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundTemplates() {
    return _buildHorizontalOptions(
      List.generate(_templates.length, (index) {
        final template = _templates[index];
        final isSelected =
            _backgroundImageFile == null && index == _selectedTemplateIndex;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTemplateIndex = index;
              _backgroundImageFile = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [template.colors.first, template.colors.last],
              ),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTextColorOptions() {
    return _buildHorizontalOptions([
      ..._textColorPresets.map((color) {
        final isSelected = _activeTextColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => _updateActiveTextColor(color),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: color.computeLuminance() > 0.75
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: isSelected ? Colors.black : Colors.transparent,
                  )
                : null,
          ),
        );
      }),
      FilledButton.tonalIcon(
        onPressed: () => _pickColor(
          initialColor: _activeTextColor,
          title: _isEditingVerse ? 'Pick Verse Color' : 'Pick Reference Color',
          onSelected: _updateActiveTextColor,
        ),
        icon: const Icon(Icons.palette_outlined),
        label: const Text('Custom'),
      ),
    ]);
  }

  Widget _buildHorizontalOptions(List<Widget> children) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            children[index],
          ],
        ],
      ),
    );
  }

  Widget _buildLayerSelector() {
    return _buildHorizontalOptions([
      ChoiceChip(
        label: const Text('Verse'),
        avatar: const Icon(Icons.text_fields, size: 18),
        selected: _selectedLayer == _EditableLayer.verse,
        onSelected: (_) {
          setState(() {
            _selectedLayer = _EditableLayer.verse;
          });
        },
      ),
      ChoiceChip(
        label: const Text('Reference'),
        avatar: const Icon(Icons.book_outlined, size: 18),
        selected: _selectedLayer == _EditableLayer.reference,
        onSelected: (_) {
          setState(() {
            _selectedLayer = _EditableLayer.reference;
          });
        },
      ),
    ]);
  }

  Widget _buildAlignmentSelector() {
    Widget chip({
      required TextAlign value,
      required IconData icon,
      required String label,
    }) {
      return ChoiceChip(
        label: Text(label),
        avatar: Icon(icon, size: 18),
        selected: _activeTextAlign == value,
        onSelected: (_) => _updateActiveTextAlign(value),
      );
    }

    return _buildHorizontalOptions([
      chip(value: TextAlign.left, icon: Icons.format_align_left, label: 'Left'),
      chip(
        value: TextAlign.center,
        icon: Icons.format_align_center,
        label: 'Center',
      ),
      chip(
        value: TextAlign.right,
        icon: Icons.format_align_right,
        label: 'Right',
      ),
      chip(
        value: TextAlign.justify,
        icon: Icons.format_align_justify,
        label: 'Justify',
      ),
    ]);
  }

  Widget _buildControls() {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: colorScheme.surfaceContainerHighest,
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Background', icon: Icon(Icons.wallpaper_outlined)),
                  Tab(text: 'Text', icon: Icon(Icons.format_size)),
                  Tab(text: 'Content', icon: Icon(Icons.edit_note)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildBackgroundTemplates(),
                      const SizedBox(height: 14),
                      _buildHorizontalOptions([
                        FilledButton.tonalIcon(
                          onPressed: () => _pickColor(
                            initialColor: _customBackgroundColor,
                            title: 'Pick Background Color',
                            onSelected: (color) {
                              setState(() {
                                _customBackgroundColor = color;
                                _backgroundImageFile = null;
                                _selectedTemplateIndex = -1;
                              });
                            },
                          ),
                          icon: const Icon(Icons.format_color_fill),
                          label: const Text('Color'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _pickBackgroundImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Image'),
                        ),
                        if (_backgroundImageFile != null)
                          FilledButton.tonalIcon(
                            onPressed: () {
                              setState(() {
                                _backgroundImageFile = null;
                                if (_selectedTemplateIndex < 0) {
                                  _selectedTemplateIndex = 0;
                                }
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Remove'),
                          ),
                      ]),
                      if (_selectedTemplateIndex < 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: _customBackgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildLayerSelector(),
                      const SizedBox(height: 14),
                      Text(
                        'Alignment',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildAlignmentSelector(),
                      const SizedBox(height: 14),
                      Text(
                        'Text Color',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildTextColorOptions(),
                      const SizedBox(height: 10),
                      Text(
                        'Size: ${_activeFontSize.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
                        value: _activeFontSize,
                        min: _isEditingVerse ? 6 : 4,
                        max: _isEditingVerse ? 64 : 34,
                        divisions: _isEditingVerse ? 46 : 22,
                        label: _activeFontSize.toStringAsFixed(0),
                        onChanged: _updateActiveFontSize,
                      ),
                      Text(
                        'Word Spacing: ${_activeWordSpacing.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
                        value: _activeWordSpacing,
                        min: 0,
                        max: 8,
                        divisions: 32,
                        label: _activeWordSpacing.toStringAsFixed(1),
                        onChanged: _updateActiveWordSpacing,
                      ),
                      if (_isEditingVerse) ...[
                        Text(
                          'Line Spacing: ${_verseLineHeight.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Slider(
                          value: _verseLineHeight,
                          min: 0.9,
                          max: 2.2,
                          divisions: 26,
                          label: _verseLineHeight.toStringAsFixed(2),
                          onChanged: (value) {
                            setState(() {
                              _verseLineHeight = value;
                            });
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _resetVersePosition,
                            icon: const Icon(Icons.center_focus_strong),
                            label: const Text('Reset Position'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _verseController,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: 'Edit verse text',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _editedVerseText = value;
                                _selectedLayer = _EditableLayer.verse;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorLayout(BoxConstraints constraints) {
    final previewHeight = constraints.maxHeight * 0.65;

    return Column(
      children: [
        SizedBox(
          height: previewHeight,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: _buildCanvasPreview(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildControls()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verse Editor'),
        actions: [
          IconButton(
            onPressed: _isSharing ? null : _shareCanvasAsImage,
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Share as Image',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildEditorLayout(constraints);
            },
          ),
        ),
      ),
    );
  }
}

class _SelectionFrame extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final bool expandToMaxWidth;
  final Duration animationDuration;

  const _SelectionFrame({
    required this.child,
    required this.isSelected,
    required this.animationDuration,
    this.expandToMaxWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expandToMaxWidth ? double.infinity : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }
}

class _BackgroundTemplate {
  final List<Color> colors;

  const _BackgroundTemplate({required this.colors});
}
