import 'package:flutter/material.dart';

import '../../services/presenter_config_service.dart';
import '../../services/server_service.dart';
import '../../services/theme_service.dart';
import '../widgets/grid_card_widget.dart';
import 'backgrounds_screen.dart';
import 'bible/bible_screen.dart';
import 'images_screen.dart';
import 'presenter/presenter_screen.dart';
import 'settings_screen.dart';
import 'songs/songs_screen.dart';

class HomeScreen extends StatelessWidget {
  final ThemeService themeService;
  final ServerService serverService;
  final PresenterConfigService presenterConfig;

  const HomeScreen({
    super.key,
    required this.themeService,
    required this.serverService,
    required this.presenterConfig,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actions = [
      _HomeAction(
        icon: Icons.music_note_rounded,
        title: 'Songs',
        subtitle: 'Build and organize worship sets quickly.',
        color: Colors.purple,
        destinationBuilder: (_) => const SongsScreen(),
      ),
      _HomeAction(
        icon: Icons.menu_book_rounded,
        title: 'Bible',
        subtitle: 'Open verses instantly while presenting.',
        color: Colors.blue,
        destinationBuilder: (_) => BibleScreen(serverService: serverService),
      ),
      _HomeAction(
        icon: Icons.photo_library_rounded,
        title: 'Images',
        subtitle: 'Show photos and media from your library.',
        color: Colors.green,
        destinationBuilder: (_) => ImagesScreen(serverService: serverService),
      ),
      _HomeAction(
        icon: Icons.wallpaper_rounded,
        title: 'Backgrounds',
        subtitle: 'Prepare stage-ready visuals for every slide.',
        color: Colors.teal,
        destinationBuilder: (_) => const BackgroundsScreen(),
      ),
      _HomeAction(
        icon: Icons.slideshow_rounded,
        title: 'Presenter',
        subtitle: 'Start presenter service.',
        color: Colors.orange,
        destinationBuilder: (_) =>
            PresenterScreen(serverService: serverService),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Church Presenter'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    themeService: themeService,
                    presenterConfig: presenterConfig,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.10),
              colorScheme.secondary.withValues(alpha: 0.06),
              colorScheme.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -40,
              child: _GlowOrb(
                color: Colors.orange.withValues(alpha: 0.14),
                size: 240,
              ),
            ),
            Positioned(
              top: 120,
              left: -70,
              child: _GlowOrb(
                color: colorScheme.primary.withValues(alpha: 0.12),
                size: 180,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isSmallScreen = width < 600;
                  final horizontalPadding = isSmallScreen ? 16.0 : 24.0;
                  final crossAxisCount = width >= 1100
                      ? 4
                      : width >= 760
                      ? 3
                      : width >= 380
                      ? 2
                      : 1;
                  final childAspectRatio = width >= 1100
                      ? 1.18
                      : width >= 760
                      ? 1.02
                      : width >= 380
                      ? 0.96
                      : 1.85;

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          18,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          24,
                        ),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final action = actions[index];
                            return GridCardWidget(
                              icon: action.icon,
                              title: action.title,
                              subtitle: action.subtitle,
                              iconColor: action.color,
                              compact: isSmallScreen,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: action.destinationBuilder,
                                  ),
                                );
                              },
                            );
                          }, childCount: actions.length),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: childAspectRatio,
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
    );
  }
}

class _HomeAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final WidgetBuilder destinationBuilder;

  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.destinationBuilder,
  });
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
