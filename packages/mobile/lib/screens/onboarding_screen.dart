import "package:flutter/material.dart";
import "../services/settings_service.dart";
import "../services/localization.dart";

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _deepseekCtrl = TextEditingController();
  final _githubTokenCtrl = TextEditingController();
  final _githubUserCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _deepseekCtrl.dispose();
    _githubTokenCtrl.dispose();
    _githubUserCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    SettingsService.deepseekApiKey = _deepseekCtrl.text.trim();
    SettingsService.githubToken = _githubTokenCtrl.text.trim();
    SettingsService.githubUser = _githubUserCtrl.text.trim();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? const Color(0xFF58A6FF)
                            : const Color(0xFF30363D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: _step == 0
                      ? _buildStep1(cs)
                      : _step == 1
                          ? _buildStep2(cs)
                          : _buildStep3(cs),
                ),
              ),

              // Buttons
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _back,
                      child: Text(AppLocalization.get("back")),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF58A6FF),
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_step == 2 ? AppLocalization.get("start") : AppLocalization.get("next"),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF58A6FF)),
        const SizedBox(height: 16),
        const Text("Welcome to OpenCode",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          "Your AI coding agent on Android. 64 skill domains, 55+ tools, 6 sub-agents. Powered by DeepSeek.",
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 32),
        Text("DeepSeek API Key",
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _deepseekCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: "sk-..."),
        ),
        const SizedBox(height: 6),
        Text("Get it at platform.deepseek.com → API Keys",
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: Color(0xFFD2991D)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You bring your own API key. We don't store or see it. Pay only for what you use.",
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildStep2(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.code, size: 48, color: Color(0xFF3FB950)),
        const SizedBox(height: 16),
        const Text("Sync with GitHub",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          "Your projects sync via GitHub. Work on your phone, continue on PC. Same repo, seamless sync.",
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 32),
        Text("GitHub Personal Access Token",
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _githubTokenCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: "ghp_..."),
        ),
        const SizedBox(height: 6),
        Text(
          "GitHub → Settings → Developer settings → Tokens → Generate (repo scope)",
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text("GitHub Username",
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _githubUserCtrl,
          decoration: const InputDecoration(hintText: "your-username"),
        ),
      ],
    );
  }

  Widget _buildStep3(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.rocket_launch, size: 48, color: Color(0xFFA371F7)),
        const SizedBox(height: 16),
        const Text("You're all set!",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 16),
        _featureRow(Icons.psychology, "7 modes: Brainstorm, Research, Architect, Code, Debug, Refactor, Auto"),
        const SizedBox(height: 12),
        _featureRow(Icons.hub, "6 sub-agents: Architect, Scribe, Debugger, Reviewer, Refactor, Researcher"),
        const SizedBox(height: 12),
        _featureRow(Icons.build, "55+ tools: files, git, GitHub API, browser, SQL, deployment, diagnostics"),
        const SizedBox(height: 12),
        _featureRow(Icons.sync, "PC-Phone sync via GitHub — work anywhere"),
        const SizedBox(height: 12),
        _featureRow(Icons.memory, "Session memory — picks up where you left off"),
        const SizedBox(height: 12),
        _featureRow(Icons.lightbulb, "18 creative ideation techniques for novel ideas"),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3FB950).withAlpha(60)),
          ),
          child: const Text(
            "You're joining the future of mobile coding. No server needed. Just your phone, your ideas, and AI.",
            style: TextStyle(fontSize: 13, color: Color(0xFF3FB950), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFFE6EDF3))),
        ),
      ],
    );
  }
}
