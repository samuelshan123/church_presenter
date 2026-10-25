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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: AppIcon(HugeIcons.strokeRoundedSun03, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: AppIcon(
                            HugeIcons.strokeRoundedMoon02,
                            size: 18,
                          ),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: AppIcon(
                            HugeIcons.strokeRoundedSmartPhone01,
                            size: 18,
                          ),
                        ),
                      ],
                      selected: {widget.themeService.themeMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          widget.themeService.setThemeMode(selection.first);
                        });
                      },
                    ),
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
