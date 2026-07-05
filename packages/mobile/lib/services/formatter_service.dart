import "dart:io";
import "storage_service.dart";

/// Code formatting via shell commands
class FormatterService {
  /// Format a file using the appropriate formatter
  static Future<String> format(String project, String filePath) async {
    final ext = filePath.split(".").last;
    final fullPath = "${StorageService.projectsRoot.path}/$project/$filePath";

    try {
      switch (ext) {
        case "ts": case "tsx": case "js": case "jsx":
          return await _run("npx prettier --write \"$fullPath\" 2>&1");
        case "py":
          return await _run("ruff format \"$fullPath\" 2>&1");
        case "dart":
          return await _run("dart format \"$fullPath\" 2>&1");
        case "rs":
          return await _run("rustfmt \"$fullPath\" 2>&1");
        case "go":
          return await _run("gofmt -w \"$fullPath\" 2>&1");
        case "java":
          return await _run("google-java-format -i \"$fullPath\" 2>&1");
        case "css": case "scss": case "less":
          return await _run("npx prettier --write \"$fullPath\" 2>&1");
        case "html":
          return await _run("npx prettier --write \"$fullPath\" 2>&1");
        case "json": case "yaml": case "yml": case "md":
          return await _run("npx prettier --write \"$fullPath\" 2>&1");
        default:
          return "No formatter available for .$ext files. Supported: ts,js,py,dart,rs,go,java,css,html,json,yaml,md";
      }
    } catch (e) {
      return "Format failed: $e. Is the formatter installed?";
    }
  }

  static Future<String> _run(String cmd) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? "cmd" : "sh",
        [Platform.isWindows ? "/c" : "-c", cmd],
        runInShell: true,
      );
      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      if (result.exitCode != 0) return "Format error: ${err.isNotEmpty ? err : out}";
      return out.isEmpty ? "Formatted successfully" : out;
    } catch (e) {
      return "Cannot run formatter: $e";
    }
  }

  /// Detect available formatters
  static Future<String> detectFormatters() async {
    final available = <String>[];
    try {
      final r = await Process.run("npx", ["prettier", "--version"], runInShell: true);
      if (r.exitCode == 0) available.add("prettier");
    } catch (_) {}
    try {
      final r = await Process.run("ruff", ["--version"], runInShell: true);
      if (r.exitCode == 0) available.add("ruff");
    } catch (_) {}
    try {
      final r = await Process.run("dart", ["format", "--help"], runInShell: true);
      if (r.exitCode == 0) available.add("dart format");
    } catch (_) {}

    return available.isEmpty
        ? "No formatters detected. Install prettier (npm), ruff (pip), or dart SDK."
        : "Available: ${available.join(", ")}";
  }
}
