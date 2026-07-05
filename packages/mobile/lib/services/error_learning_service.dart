import "dart:convert";
import "dart:io";
import "storage_service.dart";

/// Learning from mistakes — stores error patterns and avoids them next time
class ErrorLearningService {
  static const _path = ".opencode/learned-errors.json";

  /// Record an error pattern with its fix
  static Future<void> learn(
      String project, String error, String fix) async {
    final patterns = await _load(project);
    patterns.add({
      "error": error,
      "fix": fix,
      "count": 1,
      "timestamp": DateTime.now().toIso8601String(),
    });
    await _save(project, patterns);
  }

  /// Find a previously learned fix for an error
  static Future<String?> findFix(
      String project, String error) async {
    final patterns = await _load(project);
    for (final p in patterns) {
      if (error.contains(p["error"]) || p["error"].contains(error)) {
        p["count"] = (p["count"] ?? 0) + 1;
        await _save(project, patterns);
        return p["fix"];
      }
    }
    return null;
  }

  /// Get frequent error patterns for the agent's context
  static Future<String> getContext(String project) async {
    final patterns = await _load(project);
    if (patterns.isEmpty) return "";

    patterns.sort((a, b) => (b["count"] as int).compareTo(a["count"] as int));

    final buf = StringBuffer();
    buf.writeln("\n## Learned Error Patterns (from this project)");
    for (final p in patterns.take(5)) {
      buf.writeln("- Error: ${p["error"]}");
      buf.writeln("  Fix: ${p["fix"]}");
      buf.writeln("  Occurrences: ${p["count"]}");
    }
    return buf.toString();
  }

  /// Clear learned patterns
  static Future<void> clear(String project) async {
    await _save(project, []);
  }

  static Future<List<Map<String, dynamic>>> _load(
      String project) async {
    try {
      final path = ".opencode/$project/learned-errors.json";
      final content =
          await StorageService.readFile(project, _path);
      return (jsonDecode(content) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String project,
      List<Map<String, dynamic>> patterns) async {
    try {
      await StorageService.writeFile(
          project, _path, jsonEncode(patterns));
    } catch (_) {}
  }
}
