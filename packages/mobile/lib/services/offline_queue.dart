import "dart:convert";
import "dart:io";
import "storage_service.dart";
import "../services/settings_service.dart";

/// Offline action queue — stores pending actions when no internet
class OfflineQueue {
  static String get _path {
    return "${StorageService.projectsRoot.path}/../opencode-queue.json";
  }

  static Future<void> enqueue(String project, String action,
      {Map<String, dynamic>? data}) async {
    final queue = await _load();
    queue.add({
      "project": project,
      "action": action,
      "data": data ?? {},
      "timestamp": DateTime.now().toIso8601String(),
    });
    await _save(queue);
  }

  static Future<List<Map<String, dynamic>>> dequeueAll(
      String project) async {
    final queue = await _load();
    final projectQueue =
        queue.where((q) => q["project"] == project).toList();
    queue.removeWhere((q) => q["project"] == project);
    await _save(queue);
    return projectQueue;
  }

  static Future<int> pendingCount(String project) async {
    final queue = await _load();
    return queue.where((q) => q["project"] == project).length;
  }

  static Future<List<Map<String, dynamic>>> _load() async {
    final file = File(_path);
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(
      List<Map<String, dynamic>> queue) async {
    await File(_path)
        .writeAsString(const JsonEncoder.withIndent("  ").convert(queue));
  }

  /// Process pending queue for a project
  static Future<List<String>> processQueue(
      String project,
      Future<String> Function(String action, Map<String, dynamic> data)
          handler) async {
    final items = await dequeueAll(project);
    final results = <String>[];

    for (final item in items) {
      try {
        final result = await handler(
            item["action"], item["data"]);
        results.add(result);
      } catch (e) {
        results.add("Failed: ${item["action"]} — $e");
      }
    }

    return results;
  }
}
