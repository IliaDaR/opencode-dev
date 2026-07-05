import "package:flutter/material.dart";
import "../services/localization.dart";
import "../services/settings_service.dart";
import "simple_config_screen.dart";

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = "en";

  void _select(String lang) {
    setState(() => _selected = lang);
    AppLocalization.current = lang;
    SettingsService.language = lang;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.language, size: 64, color: Color(0xFF58A6FF)),
              const SizedBox(height: 24),
              Text(AppLocalization.get("select_language"),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 32),
              _langOption("en", "English", "🇬🇧"),
              const SizedBox(height: 12),
              _langOption("ru", "Русский", "🇷🇺"),
              const Spacer(),
              FilledButton(
                onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SimpleConfigScreen()),
                    );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF58A6FF),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    _selected == "ru" ? "Продолжить" : "Continue",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langOption(String code, String name, String flag) {
    final selected = _selected == code;
    return GestureDetector(
      onTap: () => _select(code),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF58A6FF).withAlpha(20)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF58A6FF)
                : const Color(0xFF30363D),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(name,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF58A6FF)
                        : Colors.white)),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF58A6FF)),
          ],
        ),
      ),
    );
  }
}
