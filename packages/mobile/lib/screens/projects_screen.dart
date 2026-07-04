import "package:flutter/material.dart";
import "../services/settings_service.dart";
import "../services/storage_service.dart";
import "../services/git_service.dart";
import "chat_screen.dart";
import "settings_screen.dart";
import "onboarding_screen.dart";

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() {
    return _ProjectsScreenState();
  }
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<String> _projects = [];
  bool _loading = true;
  final TextEditingController _cloneCtrl = TextEditingController();
  bool _cloning = false;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    if (!SettingsService.isConfigured) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const OnboardingScreen()),
        );
        await StorageService.init();
        _loadProjects();
      }
    } else {
      await StorageService.init();
      _loadProjects();
    }
  }

  Future<void> _loadProjects() async {
    final projects = await StorageService.listProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _loading = false;
      });
    }
  }

  Future<void> _cloneProject() async {
    final name = _cloneCtrl.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      _cloning = true;
    });

    final repoUrl =
        "https://github.com/${SettingsService.githubUser}/$name.git";
    final git = GitService(
        projectName: name,
        repoUrl: repoUrl,
        token: SettingsService.githubToken);

    final result = await git.clone();
    _cloneCtrl.clear();
    await _loadProjects();

    if (mounted) {
      setState(() {
        _cloning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );

      if (!result.startsWith("Clone failed")) {
        SettingsService.currentProject = name;
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                  projectName: name, gitService: git)),
        ).then((_) {
          _loadProjects();
        });
      }
    }
  }

  void _openProject(String name) {
    final repoUrl =
        "https://github.com/${SettingsService.githubUser}/$name.git";
    final git = GitService(
        projectName: name,
        repoUrl: repoUrl,
        token: SettingsService.githubToken);
    SettingsService.currentProject = name;

    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              ChatScreen(projectName: name, gitService: git)),
    ).then((_) {
      _loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenCode",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open,
                            size: 64,
                            color: cs.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text("No projects yet",
                            style: TextStyle(
                                fontSize: 18,
                                color: cs.onSurface)),
                        const SizedBox(height: 8),
                        Text(
                            "Clone a project from GitHub to get started",
                            style: TextStyle(
                                color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        _buildCloneForm(cs),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildCloneForm(cs),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: _projects.length,
                        itemBuilder: (context, index) {
                          final p = _projects[index];
                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.folder,
                                  color: cs.primary),
                              title: Text(p,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                              subtitle: const Text("Tap to open"),
                              trailing: const Icon(
                                  Icons.chevron_right),
                              onTap: () {
                                _openProject(p);
                              },
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCloneForm(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _cloneCtrl,
            decoration: const InputDecoration(
              hintText: "repository-name",
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _cloning ? null : _cloneProject,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            minimumSize: const Size(80, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _cloning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text("Clone"),
        ),
      ],
    );
  }
}
