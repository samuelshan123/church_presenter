import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'controllers/song_sync_controller.dart';
import 'services/theme_service.dart';
import 'services/server_service.dart';
import 'services/presenter_config_service.dart';
import 'services/background_service.dart';
import 'services/bible_language_service.dart';
import 'services/image_service.dart';
import 'views/features/home_screen.dart';

// Global service instances that persist throughout the app lifecycle
final PresenterConfigService globalPresenterConfig = PresenterConfigService();
final BackgroundService globalBackgroundService = BackgroundService();
final ImageService globalImageService = ImageService();
final SongSyncController globalSongSyncController = SongSyncController();
final BibleLanguageService globalBibleLanguage = BibleLanguageService();
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
    disabledBorder: borderWith(
      colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}

/// Light and dark themes share everything except brightness, so they are
/// built from one place to keep them from drifting apart.
ThemeData _buildTheme(Brightness brightness) {
  // Every button in the app shares one pill-like 30px radius.
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(30),
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: brightness,
  );
  final baseTextTheme = brightness == Brightness.light
      ? ThemeData.light().textTheme
      : ThemeData.dark().textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: brightness == Brightness.light
            ? Colors.deepPurple
            : colorScheme.onSurface,
      ),
    ),
    // Floating snackbars sit above bottom bars (broadcast controls, canvas
    // toolbar) instead of covering them edge to edge.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: buttonShape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: buttonShape,
    ),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
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
        ChangeNotifierProvider.value(value: globalBibleLanguage),
      ],
      child: MaterialApp(
        title: 'Church Presenter',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
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
