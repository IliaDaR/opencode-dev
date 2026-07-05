import "dart:io";
import "storage_service.dart";

/// Performance profiler — find bottlenecks in code
class PerformanceProfiler {
  /// Analyze a file for performance issues
  static Future<String> analyzeFile(
      String project, String filePath) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      final buf = StringBuffer();
      buf.writeln("## Performance Analysis: $filePath\n");

      var issues = 0;

      // N+1 queries
      final n1Pattern = RegExp(
          r'for\s*\(.*\)\s*\{[^}]*await\s+',
          multiLine: true,
          dotAll: true);
      for (final _ in n1Pattern.allMatches(content)) {
        buf.writeln("- 🔴 N+1 query pattern: await inside loop. Use Promise.all or batch query.");
        issues++;
      }

      // Chained array operations
      if (RegExp(r'\.filter\(.*\)\.map\(.*\)\.filter\(.*\)')
          .hasMatch(content)) {
        buf.writeln("- ⚠️ Chained filter/map/filter — combine into single loop.");
        issues++;
      }

      // Missing memoization
      if (RegExp(r'\.sort\(|\.filter\(|\.map\(|\.reduce\(')
              .hasMatch(content) &&
          !RegExp(r'useMemo|useCallback|useMemoized|computed|@Memo')
              .hasMatch(content) &&
          (filePath.contains("component") ||
          filePath.contains("view") ||
          filePath.contains("page"))) {
        buf.writeln("- ℹ️ Array operations in component — consider memoization.");
        issues++;
      }

      // Sync ops in async context
      if (RegExp(r'readFileSync|writeFileSync|existsSync|mkdirSync',
              caseSensitive: false)
          .hasMatch(content)) {
        buf.writeln("- ⚠️ Synchronous file operations — use async versions for better throughput.");
        issues++;
      }

      // Large dependencies
      final imports = RegExp(
              r'''import\s+.*?\s+from\s+['"]([^'"]+)['"]''')
          .allMatches(content)
          .map((m) => m.group(1)!)
          .toList();
      final heavyImports = imports.where((i) =>
          ["lodash", "moment", "jquery", "underscore", "ramda"]
              .any((h) => i.contains(h)));
      if (heavyImports.isNotEmpty) {
        buf.writeln("- ℹ️ Heavy dependency: ${heavyImports.join(", ")}. Consider native alternatives.");
        issues++;
      }

      // Deep nesting
      var maxDepth = 0;
      var depth = 0;
      for (var i = 0; i < content.length; i++) {
        if (content[i] == '{') depth++;
        if (content[i] == '}') depth--;
        if (depth > maxDepth) maxDepth = depth;
      }
      if (maxDepth > 5) {
        buf.writeln("- ℹ️ Deep nesting (max depth: $maxDepth). Consider extracting to functions.");
        issues++;
      }

      if (issues == 0) {
        buf.writeln("✅ No obvious performance issues found.");
      }

      return buf.toString();
    } catch (e) {
      return "Cannot analyze: $e";
    }
  }

  /// Profile an entire project for performance
  static Future<String> profileProject(String project) async {
    final buf = StringBuffer();
    buf.writeln("## Project Performance Profile: $project\n");

    var totalIssues = 0;
    var filesChecked = 0;

    await _scanDir(project, "", (file, content) {
      // Quick check for common issues
      var issues = 0;
      if (RegExp(r'for\s*\(.*\)\s*\{[^}]*await\s+', dotAll: true)
          .hasMatch(content)) issues++;
      if (RegExp(r'readFileSync|writeFileSync', caseSensitive: false)
          .hasMatch(content)) issues++;
      if (RegExp(r'console\.log|console\.warn').hasMatch(content)) issues++;

      if (issues > 0) {
        buf.writeln("### $file ($issues issue(s))");
        filesChecked++;
        totalIssues += issues;
      }
    });

    buf.writeln("\n---");
    buf.writeln(
        "Files with issues: $filesChecked | Total issues: $totalIssues");
    return buf.toString();
  }

  static Future<void> _scanDir(String project, String path,
      void Function(String file, String content) onFile) async {
    final entries =
        await StorageService.listDir(project, path);
    for (final e in entries) {
      final name = e.uri.pathSegments.last;
      final full = path.isEmpty ? name : "$path/$name";
      if (e is Directory) {
        if (name.startsWith(".") || name == "node_modules") continue;
        await _scanDir(project, full, onFile);
      } else {
        final ext = name.split(".").last;
        if (!["ts", "tsx", "js", "jsx", "py"].contains(ext)) continue;
        try {
          final content =
              await StorageService.readFile(project, full);
          onFile(full, content);
        } catch (_) {}
      }
    }
  }
}
