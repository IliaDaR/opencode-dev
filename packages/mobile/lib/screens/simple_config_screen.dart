import "package:flutter/material.dart";
import "../services/settings_service.dart";
import "../services/localization.dart";
import "chat_screen.dart";
import "settings_screen.dart";

class SimpleConfigScreen extends StatefulWidget {
  const SimpleConfigScreen({super.key});

  @override
  State<SimpleConfigScreen> createState() => _SimpleConfigScreenState();
}

class _SimpleConfigScreenState extends State<SimpleConfigScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  bool _saving = false;
  bool _showKey = false;

  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl.text = SettingsService.deepseekApiKey;
    _tokenCtrl.text = SettingsService.githubToken;
    _userCtrl.text = SettingsService.githubUser;
    _hasKey = _apiKeyCtrl.text.trim().isNotEmpty;
  }

  void _onKeyChanged(String _) {
    setState(() => _hasKey = _apiKeyCtrl.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _tokenCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndGo() async {
    SettingsService.deepseekApiKey = _apiKeyCtrl.text.trim();
    SettingsService.githubToken = _tokenCtrl.text.trim();
    SettingsService.githubUser = _userCtrl.text.trim();

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasKey = _hasKey;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF58A6FF)),
              const SizedBox(height: 16),
              Text(AppLocalization.current == "ru" ? "OpenCode" : "OpenCode",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              Text(AppLocalization.current == "ru"
                      ? "AI-агент для разработки на Android"
                      : "AI coding agent on Android",
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),

              Text(AppLocalization.current == "ru" ? "Ключ DeepSeek API" : "DeepSeek API Key",
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: !_showKey,
                autofocus: true,
                onChanged: _onKeyChanged,
                decoration: InputDecoration(
                  hintText: "sk-...",
                  suffixIcon: IconButton(
                    icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(AppLocalization.current == "ru"
                      ? "platform.deepseek.com → API Keys"
                      : "platform.deepseek.com → API Keys",
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),

              const SizedBox(height: 24),
              Text(AppLocalization.current == "ru" ? "GitHub (можно потом в чате)" : "GitHub (can add later in chat)",
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              TextField(
                controller: _tokenCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    hintText: AppLocalization.current == "ru" ? "ghp_... (необязательно)" : "ghp_... (optional)"),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _userCtrl,
                decoration: InputDecoration(
                    hintText: AppLocalization.current == "ru" ? "username (необязательно)" : "username (optional)"),
              ),

              const Spacer(),
              FilledButton(
                onPressed: hasKey && !_saving ? _saveAndGo : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF58A6FF),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalization.current == "ru" ? "Начать" : "Start",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Text(AppLocalization.current == "ru" ? "Можно пропустить GitHub и настроить позже в чате (/config)" : "Skip GitHub and configure later in chat (/config)",
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
