import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "screens/language_screen.dart";
import "screens/simple_config_screen.dart";
import "screens/chat_screen.dart";
import "services/settings_service.dart";
import "services/localization.dart";
import "services/background_service.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SettingsService.init();
  AppLocalization.current = SettingsService.language.isEmpty ? "en" : SettingsService.language;
  await BackgroundService.init();
  runApp(const OpenCodeApp());
}

class OpenCodeApp extends StatefulWidget {
  const OpenCodeApp({super.key});
  static _OpenCodeAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_OpenCodeAppState>();

  @override
  State<OpenCodeApp> createState() => _OpenCodeAppState();
}

class _OpenCodeAppState extends State<OpenCodeApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _themeMode = SettingsService.themeMode;
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      SettingsService.themeMode = _themeMode;
    });
  }

  ThemeMode get themeMode => _themeMode;

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      colorScheme: isDark
          ? const ColorScheme.dark(
              surface: Color(0xFF161B22), primary: Color(0xFF58A6FF),
              onSurface: Color(0xFFE6EDF3), onSurfaceVariant: Color(0xFF8B949E),
              error: Color(0xFFF85149),
            )
          : const ColorScheme.light(
              surface: Colors.white, primary: Color(0xFF0969DA),
              onSurface: Color(0xFF1F2328), onSurfaceVariant: Color(0xFF656D76),
              error: Color(0xFFCF222E),
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        elevation: 0, centerTitle: true,
        foregroundColor: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328),
      ),
      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(12))),
        elevation: isDark ? 0 : 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: brightness).textTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLang = SettingsService.language.isEmpty;
    final showConfig = !showLang && !SettingsService.isConfigured;

    return MaterialApp(
      title: "OpenCode",
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: showLang
          ? const LanguageScreen()
          : showConfig
              ? const SimpleConfigScreen()
              : const ChatScreen(),
    );
  }
}
