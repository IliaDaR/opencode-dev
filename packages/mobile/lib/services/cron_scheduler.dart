import "dart:convert";
import "dart:io";
import "storage_service.dart";

/// Cron-like scheduler — schedule tasks for later execution
class CronScheduler {
  static const _path = ".opencode/cron-jobs.json";

  /// Schedule a task
  static Future<String> schedule(
      String project, String task, DateTime when) async {
    final jobs = await _load(project);
    jobs.add({
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "task": task,
      "scheduled": when.toIso8601String(),
      "status": "pending",
      "created": DateTime.now().toIso8601String(),
    });
    await _save(project, jobs);
    return "Scheduled: '$task' at ${when.toIso8601String()}";
  }

  /// Schedule a recurring task (daily/weekly)
  static Future<String> scheduleRecurring(
      String project, String task, String interval,
      {DateTime? startAt}) async {
    final jobs = await _load(project);
    jobs.add({
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "task": task,
      "interval": interval, // daily, weekly, hourly
      "status": "pending",
      "next_run": (startAt ?? DateTime.now()).toIso8601String(),
      "created": DateTime.now().toIso8601String(),
    });
    await _save(project, jobs);
    return "Scheduled recurring: '$task' ($interval)";
  }

  /// List scheduled tasks
  static Future<String> list(String project) async {
    final jobs = await _load(project);
    if (jobs.isEmpty) return "No scheduled tasks.";

    final buf = StringBuffer();
    buf.writeln("## Scheduled Tasks\n");
    for (final j in jobs) {
      final status = j["status"] ?? "pending";
      final icon = status == "completed" ? "✅" : status == "cancelled" ? "❌" : "⏳";
      final task = j["task"] ?? "unknown";
      final when = j["scheduled"] ?? j["next_run"] ?? "?";
      final interval = j["interval"];
      buf.write("$icon $task");
      if (interval != null) buf.write(" (every $interval)");
      else buf.write(" — $when");
      buf.writeln();
    }
    return buf.toString();
  }

  /// Cancel a task
  static Future<String> cancel(String project, String taskPattern) async {
    final jobs = await _load(project);
    final cancelled = jobs.where((j) {
      final task = j["task"]?.toString() ?? "";
      return task.contains(taskPattern) && j["status"] == "pending";
    }).toList();

    if (cancelled.isEmpty) return "No pending tasks matching '$taskPattern'.";

    for (final j in cancelled) {
      j["status"] = "cancelled";
    }
    await _save(project, jobs);
    return "Cancelled ${cancelled.length} task(s).";
  }

  /// Mark tasks as completed (called by agent after executing)
  static Future<void> complete(String project, String taskPattern) async {
    final jobs = await _load(project);
    for (final j in jobs) {
      if ((j["task"]?.toString() ?? "").contains(taskPattern)) {
        j["status"] = "completed";
      }
    }
    await _save(project, jobs);
  }

  /// Get pending tasks that are due
  static Future<List<Map<String, dynamic>>> pending(String project) async {
    final jobs = await _load(project);
    final now = DateTime.now();
    return jobs.where((j) {
      if (j["status"] != "pending") return false;
      final scheduled = j["scheduled"] as String?;
      final nextRun = j["next_run"] as String?;
      final when = scheduled ?? nextRun;
      if (when == null) return false;
      try {
        return DateTime.parse(when).isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _load(
      String project) async {
    try {
      final content =
          await StorageService.readFile(project, _path);
      return (jsonDecode(content) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String project,
      List<Map<String, dynamic>> jobs) async {
    await StorageService.writeFile(
        project, _path, jsonEncode(jobs));
  }
}
