import "package:flutter/material.dart"
import "../services/settings_service.dart"

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key})

  @override
  State<SettingsScreen> createState() => _SettingsScreenState()
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _deepseekCtrl = TextEditingController()
  final _githubTokenCtrl = TextEditingController()
  final _githubUserCtrl = TextEditingController()
  bool _showDeepseek = false
  bool _showToken = false

  @override
  void initState() {
    super.initState()
    _deepseekCtrl.text = SettingsService.deepseekApiKey
    _githubTokenCtrl.text = SettingsService.githubToken
    _githubUserCtrl.text = SettingsService.githubUser
  }

  @override
  void dispose() {
    _deepseekCtrl.dispose()
    _githubTokenCtrl.dispose()
    _githubUserCtrl.dispose()
    super.dispose()
  }

  Future<void> _save() async {
    SettingsService.deepseekApiKey = _deepseekCtrl.text.trim()
    SettingsService.githubToken = _githubTokenCtrl.text.trim()
    SettingsService.githubUser = _githubUserCtrl.text.trim()

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved"), backgroundColor: Color(0xFF3FB950)),
      )
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("DeepSeek API Key", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _deepseekCtrl,
            obscureText: !_showDeepseek,
            decoration: InputDecoration(
              hintText: "sk-...",
              suffixIcon: IconButton(
                icon: Icon(_showDeepseek ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showDeepseek = !_showDeepseek),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text("Get at platform.deepseek.com → API Keys",
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 20),

          Text("GitHub Token", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _githubTokenCtrl,
            obscureText: !_showToken,
            decoration: InputDecoration(
              hintText: "ghp_...",
              suffixIcon: IconButton(
                icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showToken = !_showToken),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text("GitHub → Settings → Developer settings → Tokens (repo scope)",
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 20),

          Text("GitHub Username", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _githubUserCtrl,
            decoration: const InputDecoration(hintText: "your-username"),
          ),
          const SizedBox(height: 30),

          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    )
  }
}
