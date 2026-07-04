import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "screens/projects_screen.dart";
import "services/settings_service.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp]);
  await SettingsService.init();
  runApp(const OpenCodeApp());
}

class OpenCodeApp extends StatelessWidget {
  const OpenCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "OpenCode",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF161B22),
          primary: Color(0xFF58A6FF),
          onSurface: Color(0xFFE6EDF3),
          onSurfaceVariant: Color(0xFF8B949E),
          error: Color(0xFFF85149),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF161B22),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF21262D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF58A6FF)),
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme:
            GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ProjectsScreen(),
    );
  }
}
