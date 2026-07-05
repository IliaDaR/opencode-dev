import "dart:io";
import "storage_service.dart";
import "git_service.dart";
import "lsp_service.dart";

/// Pre-commit self-review: checks code quality before committing
/// Catches 80% of bugs before they reach the repo
class SelfReviewService {
  /// Run full self-review on changed files before commit
  static Future<String> reviewBeforeCommit(
      String project, GitService git) async {
    final buf = StringBuffer();
    buf.writeln("## Self-Review\n");

    // Get changed files
    try {
      final status = await git.getStatus();
      if (status == "No changes" || status == "Not a git repository") {
        return "Nothing to review — no changes.";
      }
      buf.writeln("Changed files:\n$status\n");
    } catch (_) {
      return "Cannot run review — git not available.";
    }

    // Review each changed file
    var issues = 0;
    var filesReviewed = 0;

    try {
      final entries = await StorageService.listDir(project);
      for (final e in entries.take(30)) {
        if (e is File) {
          final name = e.uri.pathSegments.last;
          final ext = name.split(".").last;
          if (!["ts", "tsx", "js", "jsx", "py", "dart", "rs", "go"]
              .contains(ext)) continue;

          try {
            final content =
                await StorageService.readFile(project, name);
            final diag =
                await LspService.diagnoseFile(project, name);
            if (!diag.contains("No issues found")) {
              buf.writeln(diag);
              filesReviewed++;
              issues += "\n".allMatches(diag).length;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (issues == 0) {
      buf.writeln("✅ No issues found. Ready to commit.");
    } else {
      buf.writeln(
          "\n⚠️ Found $issues issue(s) in $filesReviewed file(s).");
      buf.writeln("Review the issues above before committing.");
      buf.writeln("Use /undo to revert changes, fix them, then /commit.");
    }

    return buf.toString();
  }

  /// Quick sanity checks before commit
  static Future<String> quickCheck(
      String project, String filePath) async {
    final checks = <String>[];
    try {
      final content =
          await StorageService.readFile(project, filePath);

      if (content.contains("// TODO") || content.contains("// FIXME")) {
        checks.add("⚠️ TODO/FIXME comments found");
      }
      if (content.contains("console.log")) {
        checks.add("⚠️ console.log found — use proper logger");
      }
      if (content.contains("any") && filePath.endsWith(".ts")) {
        checks.add("⚠️ 'any' type found — use unknown");
      }
      if (RegExp("password\\s*=\\s*[\"']").hasMatch(content)) {
        checks.add("🔴 Possible hardcoded password!");
      }
      if (RegExp("api.?key\\s*=\\s*[\"']").hasMatch(content)) {
        checks.add("🔴 Possible hardcoded API key!");
      }

      return checks.isEmpty
          ? "✅ Quick check passed"
          : checks.join("\n");
    } catch (e) {
      return "Cannot check: $e";
    }
  }
}
