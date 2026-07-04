import "dart:io";
import "storage_service.dart";

/// Built-in code diagnostics — no external LSP servers needed.
/// Analyzes code for syntax errors, anti-patterns, and quality issues.
class LspService {
  /// Analyze a single file and return diagnostics
  static Future<String> diagnoseFile(
      String project, String filePath) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      final ext = filePath.split(".").last;
      final issues = <String>[];

      switch (ext) {
        case "ts":
        case "tsx":
        case "js":
        case "jsx":
          issues.addAll(_checkTypeScript(content, filePath));
          break;
        case "py":
          issues.addAll(_checkPython(content, filePath));
          break;
        case "dart":
          issues.addAll(_checkDart(content, filePath));
          break;
      }

      issues.addAll(_checkUniversal(content, filePath));

      if (issues.isEmpty) {
        return "No issues found in $filePath";
      }

      final buf = StringBuffer();
      buf.writeln("## Diagnostics: $filePath\n");
      buf.writeln("${issues.length} issue(s) found:\n");
      for (final issue in issues) {
        buf.writeln(issue);
      }
      return buf.toString();
    } catch (e) {
      return "Cannot analyze: $e";
    }
  }

  /// Analyze entire project
  static Future<String> analyzeProject(String project) async {
    final buf = StringBuffer();
    buf.writeln("## Project Analysis: $project\n");
    var totalIssues = 0;
    var filesAnalyzed = 0;

    Future<void> scan(String path) async {
      final entries =
          await StorageService.listDir(project, path);
      for (final entry in entries) {
        if (entry is Directory) {
          final name = entry.uri.pathSegments.last;
          if (name.startsWith(".") ||
              name == "node_modules" ||
              name == "dist" ||
              name == "build") continue;
          await scan(
              path.isEmpty ? name : "$path/$name");
        } else if (entry is File) {
          final name = entry.uri.pathSegments.last;
          final ext = name.split(".").last;
          if (!["ts", "tsx", "js", "jsx", "py", "dart"]
              .contains(ext)) continue;

          try {
            final content =
                await StorageService.readFile(
                    project,
                    path.isEmpty ? name : "$path/$name");
            final fullPath =
                path.isEmpty ? name : "$path/$name";
            var issues = <String>[];

            switch (ext) {
              case "ts":
              case "tsx":
              case "js":
              case "jsx":
                issues = _checkTypeScript(
                    content, fullPath);
              case "py":
                issues =
                    _checkPython(content, fullPath);
              case "dart":
                issues =
                    _checkDart(content, fullPath);
            }

            issues
                .addAll(_checkUniversal(content, fullPath));

            if (issues.isNotEmpty) {
              filesAnalyzed++;
              totalIssues += issues.length;
              for (final i in issues.take(3)) {
                buf.writeln(i);
              }
              if (issues.length > 3) {
                buf.writeln(
                    "  ... and ${issues.length - 3} more\n");
              }
            }
          } catch (_) {}
        }
      }
    }

    await scan("");
    buf.writeln(
        "\nAnalyzed $filesAnalyzed files with issues. Total: $totalIssues problems.");
    return buf.toString();
  }

  /// Check imports reference real files
  static Future<String> checkImports(
      String project, String filePath) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      final missing = <String>[];

      final importRegex = RegExp(
          r'''import\s+.*?\s+from\s+['"](.+?)['"]''');
      for (final m in importRegex.allMatches(content)) {
        final imp = m.group(1)!;
        if (imp.startsWith(".")) {
          final resolved = _resolveRelativeImport(
              filePath, imp);
          try {
            await StorageService.readFile(
                project, resolved);
          } catch (_) {
            try {
              await StorageService.readFile(
                  project, "$resolved.ts");
            } catch (_) {
              try {
                await StorageService.readFile(
                    project, "$resolved.tsx");
              } catch (_) {
                try {
                  await StorageService.readFile(project,
                      "$resolved/index.ts");
                } catch (_) {
                  missing.add(
                      "  Missing: $imp (resolved: $resolved)");
                }
              }
            }
          }
        }
      }

      if (missing.isEmpty) {
        return "All imports valid in $filePath";
      }
      return "Broken imports in $filePath:\n${missing.join("\n")}";
    } catch (e) {
      return "Error: $e";
    }
  }

  static String _resolveRelativeImport(
      String filePath, String importPath) {
    final dir = filePath.contains("/")
        ? filePath.substring(0, filePath.lastIndexOf("/"))
        : "";
    if (importPath.startsWith("./")) {
      return dir.isEmpty
          ? importPath.substring(2)
          : "$dir/${importPath.substring(2)}";
    }
    if (importPath.startsWith("../")) {
      var parts = dir.split("/");
      var up = importPath;
      while (up.startsWith("../")) {
        if (parts.isNotEmpty) parts.removeLast();
        up = up.substring(3);
      }
      return parts.isEmpty ? up : "${parts.join("/")}/$up";
    }
    return importPath;
  }

  static List<String> _checkTypeScript(
      String content, String filePath) {
    final issues = <String>[];

    // Check for 'any' usage
    final anyRegex = RegExp(r':\s*any\b');
    for (final m in anyRegex.allMatches(content)) {
      final line = _lineNum(content, m.start);
      issues.add(
          "- $filePath:$line ⚠️ Avoid 'any' type. Use 'unknown' instead.");
    }

    // Check for @ts-ignore / @ts-expect-error
    if (content.contains("@ts-ignore") ||
        content.contains("@ts-expect-error")) {
      issues.add(
          "- $filePath ⚠️ Contains @ts-ignore/@ts-expect-error. Fix the underlying type issue.");
    }

    // Check for console.log
    for (final m in RegExp(r'console\.(log|warn|error)\(')
        .allMatches(content)) {
      final line = _lineNum(content, m.start);
      issues.add(
          "- $filePath:$line ℹ️ console.${m.group(1)} found. Use proper logger in production.");
    }

    // Check for eval()
    if (content.contains("eval(")) {
      issues.add(
          "- $filePath 🔴 eval() detected — security risk.");
    }

    // Check for == instead of ===
    for (final m in RegExp(r'[^=!<>]==[^=]')
        .allMatches(content)) {
      final line = _lineNum(content, m.start);
      issues.add(
          "- $filePath:$line ⚠️ Use === instead of == for strict comparison.");
    }

    return issues;
  }

  static List<String> _checkPython(
      String content, String filePath) {
    final issues = <String>[];

    // bare except
    if (RegExp(r'except\s*:').hasMatch(content)) {
      issues.add(
          "- $filePath ⚠️ Bare 'except:' found. Catch specific exceptions.");
    }

    // eval/exec
    if (RegExp(r'\b(eval|exec)\s*\(').hasMatch(content)) {
      issues.add(
          "- $filePath 🔴 eval()/exec() detected — security risk.");
    }

    // print instead of logger
    for (final m
        in RegExp(r'^print\s*\(', multiLine: true)
            .allMatches(content)) {
      final line = _lineNum(content, m.start);
      issues.add(
          "- $filePath:$line ℹ️ print() found. Use proper logger in production.");
    }

    // mutable default args
    for (final m in RegExp(r'def \w+\(.*=\s*(\[\]|\{\})')
        .allMatches(content)) {
      final line = _lineNum(content, m.start);
      issues.add(
          "- $filePath:$line ⚠️ Mutable default argument. Use None and initialize inside.");
    }

    return issues;
  }

  static List<String> _checkDart(
      String content, String filePath) {
    final issues = <String>[];

    // Missing semicolons (simplified)
    final lines = content.split("\n");
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith("//") ||
          line.startsWith("import") ||
          line.startsWith("class") ||
          line.endsWith("{") ||
          line.endsWith("}") ||
          line.endsWith(";") ||
          line.endsWith(",") ||
          line.endsWith("(")) continue;
      if (line.contains("=") || line.contains("=>")) {
        issues.add(
            "- $filePath:${i + 1} ℹ️ Possible missing semicolon.");
        break;
      }
    }

    return issues;
  }

  static List<String> _checkUniversal(
      String content, String filePath) {
    final issues = <String>[];

    final lines = content.split("\n");
    final length = lines.length;
    final lineCount = length > 300 ? "${length} lines" : null;
    if (lineCount != null) {
      issues.add(
          "- $filePath 📏 $lineCount — consider splitting into smaller files.");
    }

    // TODO/FIXME comments
    for (final m in RegExp(r'(TODO|FIXME|HACK):?',
            caseSensitive: false)
        .allMatches(content)) {
      final line = _lineNum(content, m.start);
      final text =
          lines[line - 1].trim().substring(0, 80 > lines[line - 1].trim().length ? lines[line - 1].trim().length : 80);
      issues.add(
          "- $filePath:$line 📝 ${m.group(0)}: $text");
    }

    // Hardcoded secrets
    for (final pat in [
      "api_key",
      "apikey",
      "secret",
      "password",
      "token",
    ]) {
      if (RegExp('$pat\\s*=\\s*["\'][^"\']+["\']',
              caseSensitive: false)
          .hasMatch(content)) {
        issues.add(
            "- $filePath 🔴 Possible hardcoded secret: '$pat'");
        break;
      }
    }

    return issues;
  }

  static int _lineNum(String content, int position) {
    return content.substring(0, position).split("\n").length;
  }
}
