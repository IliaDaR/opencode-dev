import "dart:io";
import "storage_service.dart";

/// Code execution sandbox — run code safely and show output
class CodeSandbox {
  /// Run code and return output
  static Future<String> run(String project, String code,
      {String? language}) async {
    final lang = language ?? _detectLanguage(code);
    final tmpDir =
        "${StorageService.projectsRoot.path}/$project/.opencode/tmp";

    // Ensure tmp dir
    await Directory(tmpDir).create(recursive: true);

    switch (lang) {
      case "javascript":
      case "typescript":
        return await _runJS(project, code, tmpDir);
      case "python":
        return await _runPython(code);
      case "dart":
        return await _runDart(code);
      case "bash":
        return await _runShell(code);
      default:
        return "Unsupported language: $lang. Supported: js, ts, py, dart, sh";
    }
  }

  static String _detectLanguage(String code) {
    if (code.contains("import ") && (code.contains("from ") || code.contains("def "))) return "python";
    if (code.contains("console.log") || code.contains("const ") || code.contains("function")) return "javascript";
    if (code.contains("void main") || code.contains("import \"package:")) return "dart";
    return "javascript";
  }

  static Future<String> _runJS(String project, String code, String tmpDir) async {
    final file = File("$tmpDir/sandbox.js");
    await file.writeAsString(code);

    try {
      final result = await Process.run(
        "node",
        [file.path],
        workingDirectory:
            "${StorageService.projectsRoot.path}/$project",
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();

      await file.delete();
      if (err.isNotEmpty && out.isEmpty) return "Error:\n$err";
      if (err.isNotEmpty) return "$out\n\nStderr:\n$err";
      return out.isEmpty ? "(no output)" : out;
    } catch (e) {
      await file.delete();
      return "Sandbox error: $e";
    }
  }

  static Future<String> _runPython(String code) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? "python" : "python3",
        ["-c", code],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      if (err.isNotEmpty && out.isEmpty) return "Error:\n$err";
      if (err.isNotEmpty) return "$out\n\n$err";
      return out.isEmpty ? "(no output)" : out;
    } catch (e) {
      return "Sandbox error: $e. Is Python installed?";
    }
  }

  static Future<String> _runDart(String code) async {
    try {
      final result = await Process.run(
        "dart",
        ["run", "-c", code],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));
      final out = (result.stdout as String).trim();
      return out.isEmpty ? "(no output)" : out;
    } catch (e) {
      return "Sandbox error: $e. Is Dart installed?";
    }
  }

  static Future<String> _runShell(String code) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? "cmd" : "sh",
        [Platform.isWindows ? "/c" : "-c", code],
        runInShell: true,
      ).timeout(const Duration(seconds: 10));
      final out = (result.stdout as String).trim();
      return out.isEmpty ? "(no output)" : out;
    } catch (e) {
      return "Sandbox error: $e";
    }
  }
}
