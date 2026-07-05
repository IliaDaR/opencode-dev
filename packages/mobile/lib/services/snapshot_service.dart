import "dart:convert";
import "dart:io";
import "storage_service.dart";

/// File versioning with undo support.
/// Before every write/edit/delete, takes a snapshot.
/// Undo restores the previous version.
class SnapshotService {
  static const _snapDir = "opencode-snapshots";

  static Future<void> init() async {
    final dir = Directory("${StorageService.projectsRoot.path}/../$_snapDir");
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  static String _path(String project, String filePath) {
    return "${StorageService.projectsRoot.path}/../$_snapDir/$project/${filePath.hashCode}.json";
  }

  /// Take a snapshot of a file before modifying it
  static Future<void> snapshot(String project, String filePath) async {
    try {
      final content = await StorageService.readFile(project, filePath);
      final entry = {
        "project": project,
        "path": filePath,
        "content": content,
        "timestamp": DateTime.now().toIso8601String(),
      };
      final p = _path(project, filePath);
      final dir = Directory(p).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(p).writeAsString(jsonEncode(entry));
    } catch (_) {
      // File doesn't exist yet — that's fine, write_file will create it
    }
  }

  /// Restore the most recent snapshot (undo last change)
  static Future<String> undo(String project, String filePath) async {
    final p = _path(project, filePath);
    final file = File(p);
    if (!await file.exists()) return "Nothing to undo for $filePath";

    try {
      final entry = jsonDecode(await file.readAsString());
      final content = entry["content"] as String;
      await StorageService.writeFile(project, filePath, content);
      await file.delete();
      return "Undone: $filePath restored to previous version";
    } catch (e) {
      return "Undo failed: $e";
    }
  }

  /// List all snapshots for a project
  static Future<List<Map<String, dynamic>>> listSnapshots(String project) async {
    final dir = Directory("${StorageService.projectsRoot.path}/../$_snapDir/$project");
    if (!await dir.exists()) return [];

    final snaps = <Map<String, dynamic>>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith(".json")) {
        try {
          snaps.add(jsonDecode(await f.readAsString()));
        } catch (_) {}
      }
    }
    snaps.sort((a, b) => (b["timestamp"] as String).compareTo(a["timestamp"] as String));
    return snaps;
  }

  /// Undo ALL snapshots for a project
  static Future<String> undoAll(String project) async {
    final snaps = await listSnapshots(project);
    if (snaps.isEmpty) return "Nothing to undo.";

    var count = 0;
    for (final s in snaps) {
      final r = await undo(s["project"], s["path"]);
      if (!r.startsWith("Undo failed")) count++;
    }
    return "Undone $count file(s).";
  }
}
