import "dart:convert";
import "dart:io";
import "storage_service.dart";
import "git_service.dart";

/// Session sharing via GitHub — export chat history to repo
class SessionSharingService {
  /// Export current session to .opencode/sessions/ in the project
  static Future<String> exportSession(
      String project, List<Map<String, dynamic>> messages,
      {GitService? gitService}) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(":", "-")
        .split(".")[0];
    final fileName = "session-$timestamp.md";

    final buf = StringBuffer();
    buf.writeln("# OpenCode Session — $timestamp");
    buf.writeln("Project: $project\n");

    for (final m in messages) {
      final role = m["role"] ?? "unknown";
      final content = m["content"]?.toString() ?? "";

      switch (role) {
        case "user":
          buf.writeln("## You\n$content\n");
          break;
        case "assistant":
          buf.writeln("## OpenCode\n$content\n");
          break;
        case "tool":
          buf.writeln("### Tool Result\n```\n${_trunc(content, 2000)}\n```\n");
          break;
        case "system":
          if (!content.startsWith("You are") && !content.startsWith("## MODE")) {
            buf.writeln("*$content*\n");
          }
          break;
      }
    }

    final path = ".opencode/sessions/$fileName";
    await StorageService.writeFile(project, path, buf.toString());

    // Commit and push if git configured
    if (gitService != null) {
      try {
        final r = await gitService.commitAndPush("docs: session export $timestamp");
        return "Session exported to $path and pushed to GitHub\n$r";
      } catch (e) {
        return "Session exported to $path (push failed: $e)";
      }
    }

    return "Session exported to $path";
  }

  /// Generate a shareable summary
  static String generateShareSummary(
      List<Map<String, dynamic>> messages) {
    final buf = StringBuffer();
    buf.writeln("# OpenCode Session Summary\n");

    // Extract key info
    final userMessages =
        messages.where((m) => m["role"] == "user").length;
    final assistantMessages =
        messages.where((m) => m["role"] == "assistant").length;
    final toolCalls = messages.where((m) => m["role"] == "tool").length;

    buf.writeln("Messages: $userMessages user, $assistantMessages assistant, $toolCalls tools\n");

    // Last 3 exchanges
    buf.writeln("## Recent Activity\n");
    final recent = messages.reversed.take(6).toList().reversed;
    for (final m in recent) {
      final role = m["role"];
      final content = _trunc(m["content"]?.toString() ?? "", 200);
      if (role == "user") buf.writeln("**You:** $content\n");
      if (role == "assistant") buf.writeln("**OpenCode:** $content\n");
    }

    return buf.toString();
  }

  static String _trunc(String text, int max) {
    if (text.length <= max) return text;
    return "${text.substring(0, max)}...";
  }
}
