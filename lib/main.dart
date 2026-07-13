import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'controllers/song_sync_controller.dart';
import 'services/theme_service.dart';
import 'services/server_service.dart';
import 'services/presenter_config_service.dart';
import 'services/background_service.dart';
import 'services/image_service.dart';
import 'views/features/home_screen.dart';

// Global service instances that persist throughout the app lifecycle
final PresenterConfigService globalPresenterConfig = PresenterConfigService();
final BackgroundService globalBackgroundService = BackgroundService();
final ImageService globalImageService = ImageService();
final SongSyncController globalSongSyncController = SongSyncController();
final ServerService globalServerService = ServerService(
  presenterConfig: globalPresenterConfig,
  backgroundService: globalBackgroundService,
  imageService: globalImageService,
);

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MainApp());
}

/// App-wide text field styling — every [TextField]/[TextFormField] should
/// inherit this instead of specifying its own `border`/`filled`, so inputs
/// look consistent across screens.
InputDecorationTheme _buildInputDecorationTheme(ColorScheme colorScheme) {
  final radius = BorderRadius.circular(12);
  OutlineInputBorder borderWith(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecorationTheme(
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
    border: borderWith(colorScheme.outlineVariant),
    enabledBorder: borderWith(colorScheme.outlineVariant),
    focusedBorder: borderWith(colorScheme.primary, width: 2),
    errorBorder: borderWith(colorScheme.error),
    focusedErrorBorder: borderWith(colorScheme.error, width: 2),
    disabledBorder: borderWith(colorScheme.outlineVariant.withValues(alpha: 0.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
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
    FlutterNativeSplash.remove();
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
        ChangeNotifierProvider.value(value: globalSongSyncController),
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
          inputDecorationTheme: _buildInputDecorationTheme(
            ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
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
          inputDecorationTheme: _buildInputDecorationTheme(
            ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
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
