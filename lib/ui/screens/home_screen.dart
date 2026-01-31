import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/server_service.dart';
import '../../services/presenter_config_service.dart';
import '../widgets/grid_card_widget.dart';
import 'songs/songs_screen.dart';
import 'bible/bible_screen.dart';
import 'backgrounds_screen.dart';
import 'images_screen.dart';
import 'presenter/presenter_screen.dart';
import 'settings_screen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Church Presenter',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      GridCardWidget(
                        icon: Icons.music_note,
                        title: 'Songs',
                        iconColor: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SongsScreen(),
                            ),
                          );
                        },
                      ),
                      GridCardWidget(
                        icon: Icons.book,
                        title: 'Bible',
                        iconColor: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BibleScreen(serverService: serverService),
                            ),
                          );
                        },
                      ),
                      GridCardWidget(
                        icon: Icons.photo_library,
                        title: 'Images',
                        iconColor: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ImagesScreen(serverService: serverService),
                            ),
                          );
                        },
                      ),
                      GridCardWidget(
                        icon: Icons.image,
                        title: 'Backgrounds',
                        iconColor: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BackgroundsScreen(),
                            ),
                          );
                        },
                      ),
                      GridCardWidget(
                        icon: Icons.slideshow,
                        title: 'Presenter',
                        iconColor: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PresenterScreen(serverService: serverService),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
