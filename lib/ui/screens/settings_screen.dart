import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../services/theme_service.dart';
import '../../services/presenter_config_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeService themeService;
  final PresenterConfigService presenterConfig;

  const SettingsScreen({
    super.key,
    required this.themeService,
    required this.presenterConfig,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.brightness_6,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Theme Mode'),
                  subtitle: Text(_getThemeModeText()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('Light'),
                        subtitle: const Text('Always use light theme'),
                        value: ThemeMode.light,
                        groupValue: widget.themeService.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) {
                            setState(() {
                              widget.themeService.setThemeMode(value);
                            });
                          }
                        },
                        secondary: const Icon(Icons.light_mode),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark'),
                        subtitle: const Text('Always use dark theme'),
                        value: ThemeMode.dark,
                        groupValue: widget.themeService.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) {
                            setState(() {
                              widget.themeService.setThemeMode(value);
                            });
                          }
                        },
                        secondary: const Icon(Icons.dark_mode),
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('System'),
                        subtitle: const Text('Follow system settings'),
                        value: ThemeMode.system,
                        groupValue: widget.themeService.themeMode,
                        onChanged: (ThemeMode? value) {
                          if (value != null) {
                            setState(() {
                              widget.themeService.setThemeMode(value);
                            });
                          }
                        },
                        secondary: const Icon(Icons.auto_awesome),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.tv,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Presenter Settings'),
                  subtitle: const Text('Customize presentation display'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Font Size Slider
                      Text(
                        'Font Size: ${widget.presenterConfig.fontSize.toInt()}px',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Slider(
                        value: widget.presenterConfig.fontSize,
                        min: 24,
                        max: 120,
                        divisions: 96,
                        label: widget.presenterConfig.fontSize
                            .toInt()
                            .toString(),
                        onChanged: (value) {
                          setState(() {
                            widget.presenterConfig.setFontSize(value);
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Background Color
                      Text(
                        'Background Color',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () =>
                                _showColorPicker(context, isBackground: true),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color:
                                    widget.presenterConfig.bgColorValue ??
                                    Colors.black,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: widget.presenterConfig.bgColor == 'default'
                                  ? const Center(
                                      child: Text(
                                        'DEF',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.presenterConfig.bgColor == 'default'
                                      ? 'Default (Black Gradient)'
                                      : widget.presenterConfig.bgColor,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                if (widget.presenterConfig.bgColor != 'default')
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        widget.presenterConfig.setBgColor(
                                          'default',
                                        );
                                      });
                                    },
                                    child: const Text('Reset to Default'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Foreground Color
                      Text(
                        'Text Color',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () =>
                                _showColorPicker(context, isBackground: false),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color:
                                    widget.presenterConfig.fgColorValue ??
                                    Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: widget.presenterConfig.fgColor == 'default'
                                  ? const Center(
                                      child: Text(
                                        'DEF',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.presenterConfig.fgColor == 'default'
                                      ? 'Default (White)'
                                      : widget.presenterConfig.fgColor,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                if (widget.presenterConfig.fgColor != 'default')
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        widget.presenterConfig.setFgColor(
                                          'default',
                                        );
                                      });
                                    },
                                    child: const Text('Reset to Default'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Language'),
              subtitle: const Text('Select preferred language'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.notifications,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Notifications'),
              subtitle: const Text('Manage notifications'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeText() {
    switch (widget.themeService.themeMode) {
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showColorPicker(BuildContext context, {required bool isBackground}) {
    Color currentColor = isBackground
        ? (widget.presenterConfig.bgColorValue ?? Colors.black)
        : (widget.presenterConfig.fgColorValue ?? Colors.white);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isBackground ? 'Pick Background Color' : 'Pick Text Color',
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                currentColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final hexColor = widget.presenterConfig.colorToHex(
                    currentColor,
                  );
                  if (isBackground) {
                    widget.presenterConfig.setBgColor(hexColor);
                  } else {
                    widget.presenterConfig.setFgColor(hexColor);
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }
}
