import 'package:flutter/material.dart';

import '../../../../models/canvas_models.dart';
import '../../../../services/canvas_overlay_service.dart';

/// Tool, colour, width, and history controls for the canvas.
///
/// Calls [onChanged] after any action that alters what displays should show, so
/// the screen can rebroadcast. Tool/colour changes deliberately don't fire it —
/// they only affect the *next* stroke, not the current picture.
class CanvasToolbar extends StatelessWidget {
  final CanvasOverlayService canvas;
  final bool selecting;
  final ValueChanged<bool> onSelectingChanged;
  final VoidCallback onAddImage;
  final VoidCallback onChanged;

  const CanvasToolbar({
    super.key,
    required this.canvas,
    required this.selecting,
    required this.onSelectingChanged,
    required this.onAddImage,
    required this.onChanged,
  });

  static const List<Color> _palette = [
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF0A84FF),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSelection = canvas.selectedImage != null;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolButton(
                      icon: Icons.edit_rounded,
                      label: 'Pen',
                      selected: !selecting && canvas.tool == DrawTool.pen,
                      onTap: () {
                        onSelectingChanged(false);
                        canvas.setTool(DrawTool.pen);
                      },
                    ),
                    _ToolButton(
                      icon: Icons.brush_rounded,
                      label: 'Marker',
                      selected: !selecting && canvas.tool == DrawTool.highlighter,
                      onTap: () {
                        onSelectingChanged(false);
                        canvas.setTool(DrawTool.highlighter);
                      },
                    ),
                    _ToolButton(
                      icon: Icons.auto_fix_normal_rounded,
                      label: 'Erase',
                      selected: !selecting && canvas.tool == DrawTool.eraser,
                      onTap: () {
                        onSelectingChanged(false);
                        canvas.setTool(DrawTool.eraser);
                      },
                    ),
                    _ToolButton(
                      icon: Icons.open_with_rounded,
                      label: 'Move',
                      selected: selecting,
                      onTap: () => onSelectingChanged(true),
                    ),
                    const SizedBox(width: 8),
                    const VerticalDivider(width: 1),
                    const SizedBox(width: 8),
                    _ToolButton(
                      icon: Icons.image_outlined,
                      label: 'Image',
                      selected: false,
                      onTap: onAddImage,
                    ),
                    _ToolButton(
                      icon: Icons.undo_rounded,
                      label: 'Undo',
                      selected: false,
                      enabled: canvas.canUndo,
                      onTap: () {
                        canvas.undo();
                        onChanged();
                      },
                    ),
                    _ToolButton(
                      icon: Icons.redo_rounded,
                      label: 'Redo',
                      selected: false,
                      enabled: canvas.canRedo,
                      onTap: () {
                        canvas.redo();
                        onChanged();
                      },
                    ),
                    _ToolButton(
                      icon: Icons.delete_sweep_rounded,
                      label: 'Clear',
                      selected: false,
                      enabled: !canvas.isEmpty,
                      onTap: () => _confirmClear(context),
                    ),
                  ],
                ),
              ),

              // Image actions only appear when something is actually selected,
              // so the bar stays uncluttered while drawing.
              if (selecting && hasSelection) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        canvas.bringSelectedToFront();
                        onChanged();
                      },
                      icon: const Icon(Icons.flip_to_front_rounded, size: 18),
                      label: const Text('Bring to front'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        canvas.deleteSelectedImage();
                        onChanged();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],

              if (!selecting && canvas.tool != DrawTool.eraser) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final color in _palette)
                      _ColorDot(
                        color: color,
                        selected: canvas.color.toARGB32() == color.toARGB32(),
                        onTap: () => canvas.setColor(color),
                      ),
                    Expanded(
                      child: Slider(
                        value: canvas.strokeWidth,
                        min: 0.002,
                        max: 0.03,
                        onChanged: canvas.setStrokeWidth,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear canvas?'),
        content: const Text(
          'Removes every image and stroke. This can be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      canvas.clear();
      onChanged();
    }
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.3)
        : selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
