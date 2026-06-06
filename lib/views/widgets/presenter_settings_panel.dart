import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../services/presenter_config_service.dart';

/// Reusable presenter settings panel.
/// Used in the Settings screen and in the quick-access dialog on detail screens.
class PresenterSettingsPanel extends StatefulWidget {
  final PresenterConfigService presenterConfig;

  const PresenterSettingsPanel({super.key, required this.presenterConfig});

  @override
  State<PresenterSettingsPanel> createState() => _PresenterSettingsPanelState();
}

class _PresenterSettingsPanelState extends State<PresenterSettingsPanel> {
  @override
  void initState() {
    super.initState();
    widget.presenterConfig.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    widget.presenterConfig.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() => setState(() {});

  void _showColorPicker(BuildContext context, {required bool isBackground}) {
    Color currentColor = isBackground
        ? (widget.presenterConfig.bgColorValue ?? Colors.black)
        : (widget.presenterConfig.fgColorValue ?? Colors.white);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isBackground ? 'Pick Background Color' : 'Pick Text Color',
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => currentColor = color,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final hex =
                  widget.presenterConfig.colorToHex(currentColor);
              if (isBackground) {
                widget.presenterConfig.setBgColor(hex);
              } else {
                widget.presenterConfig.setFgColor(hex);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Font Size ──────────────────────────────────────────────────────
        Text(
          'Font Size: ${widget.presenterConfig.fontSize.toInt()}px',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider(
          value: widget.presenterConfig.fontSize,
          min: 24,
          max: 120,
          divisions: 96,
          label: widget.presenterConfig.fontSize.toInt().toString(),
          onChanged: (value) => widget.presenterConfig.setFontSize(value),
        ),
        const SizedBox(height: 16),

        // ── Background Color ───────────────────────────────────────────────
        Text(
          'Background Color',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _ColorSwatch(
          color: widget.presenterConfig.bgColorValue ?? Colors.black,
          isDefault: widget.presenterConfig.bgColor == 'default',
          defaultLabel: 'Default (Black Gradient)',
          currentLabel: widget.presenterConfig.bgColor,
          onTap: () => _showColorPicker(context, isBackground: true),
          onReset: widget.presenterConfig.bgColor != 'default'
              ? () => widget.presenterConfig.setBgColor('default')
              : null,
        ),
        const SizedBox(height: 16),

        // ── Text Color ─────────────────────────────────────────────────────
        Text(
          'Text Color',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _ColorSwatch(
          color: widget.presenterConfig.fgColorValue ?? Colors.white,
          isDefault: widget.presenterConfig.fgColor == 'default',
          defaultLabel: 'Default (White)',
          currentLabel: widget.presenterConfig.fgColor,
          foregroundForDefault: Colors.black,
          onTap: () => _showColorPicker(context, isBackground: false),
          onReset: widget.presenterConfig.fgColor != 'default'
              ? () => widget.presenterConfig.setFgColor('default')
              : null,
        ),
      ],
    );
  }
}

// ── Mini color swatch row ──────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isDefault;
  final String defaultLabel;
  final String currentLabel;
  final Color foregroundForDefault;
  final VoidCallback onTap;
  final VoidCallback? onReset;

  const _ColorSwatch({
    required this.color,
    required this.isDefault,
    required this.defaultLabel,
    required this.currentLabel,
    this.foregroundForDefault = Colors.white,
    required this.onTap,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isDefault
                ? Center(
                    child: Text(
                      'DEF',
                      style: TextStyle(
                        color: foregroundForDefault,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDefault ? defaultLabel : currentLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onReset != null)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reset to Default'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows a quick-access presenter settings dialog.
/// Call from any screen that imports this file.
void showPresenterSettingsDialog(
  BuildContext context,
  PresenterConfigService presenterConfig,
) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Presenter Settings'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SingleChildScrollView(
        child: PresenterSettingsPanel(presenterConfig: presenterConfig),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
