import "dart:io";
import "storage_service.dart";
import "git_service.dart";

/// Daily standup — agent summarizes what was done today
class DailyStandupService {
  /// Generate a daily summary from git log
  static Future<String> generate(
      String project, GitService git) async {
    final buf = StringBuffer();
    buf.writeln(
        "## Daily Standup — ${DateTime.now().toIso8601String().split("T")[0]}\n");

    // Recent commits
    try {
      final log = await git.getLog(limit: 15);
      final today = DateTime.now().toIso8601String().split("T")[0];

      buf.writeln("### Recent Commits\n");
      for (final commit in log) {
        buf.writeln("- $commit");
      }
      buf.writeln();
    } catch (_) {
      buf.writeln("No git history available.\n");
    }

    // Changed files
    try {
      final status = await git.getStatus();
      buf.writeln("### Current Status\n$status\n");
    } catch (_) {}

    // Project stats
    try {
      var files = 0;
      var dirs = 0;
      final entries =
          await StorageService.listDir(project);
      for (final e in entries.take(50)) {
        if (e is Directory) dirs++;
        else files++;
      }
      buf.writeln(
          "### Project Stats\n$files files, $dirs directories");
    } catch (_) {}

    return buf.toString();
  }

  /// Weekly retrospective
  static Future<String> retrospective(
      String project, GitService git) async {
    final buf = StringBuffer();
    buf.writeln("## Weekly Retrospective\n");

    try {
      final log = await git.getLog(limit: 50);
      final commits = log.where((l) => l.trim().isNotEmpty).toList();

      final features =
          commits.where((c) => c.toLowerCase().contains("feat")).length;
      final fixes =
          commits.where((c) => c.toLowerCase().contains("fix")).length;
      final chores =
          commits.where((c) => c.toLowerCase().contains("chore")).length;

      buf.writeln("### This Week");
      buf.writeln("- Features: $features");
      buf.writeln("- Bug fixes: $fixes");
      buf.writeln("- Maintenance: $chores");
      buf.writeln("- Total commits: ${commits.length}");
      buf.writeln();

      buf.writeln("### Key Changes");
      for (final c in commits.take(10)) {
        buf.writeln("- $c");
      }
    } catch (_) {
      buf.writeln("No git history.");
    }

    return buf.toString();
  }
}
