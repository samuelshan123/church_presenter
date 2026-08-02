import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/presenter_config_service.dart';
import '../widgets/presenter_settings_panel.dart';
import 'package:hugeicons/hugeicons.dart';
import '../widgets/app_icon.dart';

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
                  leading: AppIcon(
                    HugeIcons.strokeRoundedSun03,
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
                        secondary: AppIcon(HugeIcons.strokeRoundedSun03),
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
                        secondary: AppIcon(HugeIcons.strokeRoundedMoon02),
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
                        secondary: AppIcon(HugeIcons.strokeRoundedSparkles),
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
                  leading: AppIcon(
                    HugeIcons.strokeRoundedTv01,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Presenter Settings'),
                  subtitle: const Text('Customize presentation display'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: PresenterSettingsPanel(
                    presenterConfig: widget.presenterConfig,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: AppIcon(
                HugeIcons.strokeRoundedGlobe02,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Language'),
              subtitle: const Text('Select preferred language'),
              trailing: AppIcon(HugeIcons.strokeRoundedArrowRight01),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: AppIcon(
                HugeIcons.strokeRoundedNotification02,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Notifications'),
              subtitle: const Text('Manage notifications'),
              trailing: AppIcon(HugeIcons.strokeRoundedArrowRight01),
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
}
