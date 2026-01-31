import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'services/server_service.dart';
import 'services/presenter_config_service.dart';
import 'services/background_service.dart';
import 'services/image_service.dart';
import 'ui/screens/home_screen.dart';

// Global service instances that persist throughout the app lifecycle
final PresenterConfigService globalPresenterConfig = PresenterConfigService();
final BackgroundService globalBackgroundService = BackgroundService();
final ImageService globalImageService = ImageService();
final ServerService globalServerService = ServerService(
  presenterConfig: globalPresenterConfig,
  backgroundService: globalBackgroundService,
  imageService: globalImageService,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(() {
      setState(() {});
    });
    globalServerService.addListener(() {
      setState(() {});
    });
    globalPresenterConfig.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeService.dispose();
    // Don't dispose globalServerService here, only stop it
    globalServerService.stopServer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep server running even when app goes to background
    if (state == AppLifecycleState.paused) {
      print('📱 App paused - server still running');
    } else if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - server still running');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: globalBackgroundService),
        ChangeNotifierProvider.value(value: globalPresenterConfig),
        ChangeNotifierProvider.value(value: globalImageService),
      ],
      child: MaterialApp(
        title: 'Church Presenter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        themeMode: _themeService.themeMode,
        home: HomeScreen(
          themeService: _themeService,
          serverService: globalServerService,
          presenterConfig: globalPresenterConfig,
        ),
      ),
    );
  }
}
