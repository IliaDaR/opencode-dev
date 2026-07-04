import "dart:io";
import "package:flutter/material.dart";
import "../services/storage_service.dart";

class FileBrowserScreen extends StatefulWidget {
  final String projectName;

  const FileBrowserScreen({super.key, required this.projectName});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  String _currentPath = "";
  List<FileSystemEntity> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDir("");
  }

  Future<void> _loadDir(String path) async {
    setState(() => _loading = true);
    try {
      final entries = await StorageService.listDir(
          widget.projectName, path);
      if (mounted) {
        setState(() {
          _currentPath = path;
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Cannot read directory: $e")));
      }
    }
  }

  void _navigateTo(String dirName) {
    final newPath =
        _currentPath.isEmpty ? dirName : "$_currentPath/$dirName";
    _loadDir(newPath);
  }

  void _goUp() {
    if (_currentPath.isEmpty) return;
    final parts = _currentPath.split("/");
    parts.removeLast();
    _loadDir(parts.join("/"));
  }

  Future<void> _viewFile(String fileName) async {
    final path = _currentPath.isEmpty
        ? fileName
        : "$_currentPath/$fileName";
    try {
      final content = await StorageService.readFile(
          widget.projectName, path);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FileViewScreen(
              projectName: widget.projectName,
              filePath: path,
              fileName: fileName,
              content: content,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cannot read: $e")),
        );
      }
    }
  }

  IconData _fileIcon(String name) {
    final ext = name.split(".").last.toLowerCase();
    return switch (ext) {
      "dart" => Icons.flutter_dash,
      "js" || "ts" || "jsx" || "tsx" => Icons.javascript,
      "py" => Icons.code,
      "html" || "css" => Icons.web,
      "json" || "yaml" || "yml" || "toml" => Icons.settings,
      "md" || "mdx" => Icons.article,
      "sql" => Icons.storage,
      "sh" || "bash" || "zsh" => Icons.terminal,
      "png" || "jpg" || "jpeg" || "gif" || "svg" => Icons.image,
      "gitignore" || "dockerignore" => Icons.visibility_off,
      _ => Icons.insert_drive_file,
    };
  }

  Color _fileColor(String name) {
    final ext = name.split(".").last.toLowerCase();
    return switch (ext) {
      "dart" => const Color(0xFF00B4AB),
      "js" || "ts" || "jsx" || "tsx" => const Color(0xFFF7DF1E),
      "py" => const Color(0xFF3572A5),
      "html" => const Color(0xFFE34F26),
      "css" => const Color(0xFF1572B6),
      "json" => const Color(0xFF8B949E),
      "md" => const Color(0xFF58A6FF),
      "sql" => const Color(0xFF336791),
      _ => const Color(0xFF8B949E),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final dirs = _entries.whereType<Directory>().take(200).toList();
    final files = _entries.whereType<File>().take(200).toList();
    final truncated = _entries.length > 400;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _currentPath.isEmpty
                ? widget.projectName
                : _currentPath.split("/").last,
            style: const TextStyle(fontSize: 15)),
        leading: _currentPath.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: _goUp,
              )
            : null,
        actions: [
          Text(_currentPath.isEmpty ? "/" : _currentPath,
              style: TextStyle(
                  fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (_currentPath.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.arrow_upward,
                        color: Color(0xFF58A6FF)),
                    title: const Text("..",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: _goUp,
                    dense: true,
                  ),
                ...dirs.map((d) {
                  final name = d.uri.pathSegments.last;
                  return ListTile(
                    leading: const Icon(Icons.folder,
                        color: Color(0xFF58A6FF), size: 22),
                    title: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right,
                        size: 18),
                    onTap: () => _navigateTo(name),
                    dense: true,
                  );
                }),
                ...files.map((f) {
                  final name = f.uri.pathSegments.last;
                  return ListTile(
                    leading: Icon(_fileIcon(name),
                        color: _fileColor(name), size: 20),
                    title: Text(name,
                        style: const TextStyle(fontSize: 13)),
                    onTap: () => _viewFile(name),
                    dense: true,
                  );
                }),
                if (dirs.isEmpty && files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text("Empty directory",
                            style: TextStyle(
                                color: Color(0xFF8B949E)))),
                  ),
                if (truncated)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: Text("Showing first 400 entries...",
                            style: TextStyle(
                                color: Color(0xFF8B949E)))),
                  ),
              ],
            ),
    );
  }
}

class FileViewScreen extends StatelessWidget {
  final String projectName;
  final String filePath;
  final String fileName;
  final String content;

  const FileViewScreen({
    super.key,
    required this.projectName,
    required this.filePath,
    required this.fileName,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName,
            style: const TextStyle(
                fontSize: 14, fontFamily: "monospace")),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: "Edit",
            onPressed: () {
              Navigator.of(context).pop();
              // Could open an editor, but for now just view
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          content,
          style: TextStyle(
            fontFamily: "monospace",
            fontSize: 12,
            color: cs.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
