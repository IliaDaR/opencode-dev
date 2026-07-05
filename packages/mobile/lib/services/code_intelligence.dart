import "dart:io";
import "storage_service.dart";

/// Deep code understanding — import graph, impact analysis, patterns
class CodeIntelligence {
  /// Build an import/dependency graph for the project
  static Future<Map<String, List<String>>> buildImportGraph(
      String projectName) async {
    final graph = <String, List<String>>{};

    Future<void> scanDir(String path) async {
      final entries =
          await StorageService.listDir(projectName, path);
      for (final entry in entries) {
        if (entry is Directory) {
          final name = entry.uri.pathSegments.last;
          if (name.startsWith(".") ||
              name == "node_modules" ||
              name == "dist" ||
              name == "build" ||
              name == "__pycache__") {
            continue;
          }
          await scanDir(
              path.isEmpty ? name : "$path/$name");
        } else if (entry is File) {
          final name = entry.uri.pathSegments.last;
          final imports = await _extractImports(
              projectName,
              path.isEmpty ? name : "$path/$name");
          final filePath =
              path.isEmpty ? name : "$path/$name";
          graph[filePath] = imports;
        }
      }
    }

    await scanDir("");
    return graph;
  }

  /// Extract imports from a source file
  static Future<List<String>> _extractImports(
      String projectName, String filePath) async {
    try {
      final content = await StorageService.readFile(
          projectName, filePath);
      final imports = <String>[];
      final ext = filePath.split(".").last;

      if (ext == "ts" || ext == "tsx" || ext == "js" || ext == "jsx") {
        final regex = RegExp(
            r'''import\s+.*?\s+from\s+['"]([^'"]+)['"]''');
        for (final match in regex.allMatches(content)) {
          imports.add(match.group(1)!);
        }
        final reqRegex =
            RegExp(r'''require\s*\(['"]([^'"]+)['"]\)''');
        for (final match in reqRegex.allMatches(content)) {
          imports.add(match.group(1)!);
        }
      } else if (ext == "py") {
        final regex =
            RegExp(r'''^(?:from|import)\s+([\w.]+)''', multiLine: true);
        for (final match in regex.allMatches(content)) {
          imports.add(match.group(1)!);
        }
      } else if (ext == "dart") {
        final regex = RegExp(
            r'''import\s+['"]([^'"]+)['"]''');
        for (final match in regex.allMatches(content)) {
          imports.add(match.group(1)!);
        }
      } else if (ext == "rs") {
        final regex = RegExp(r'^use\s+([\w:]+)', multiLine: true);
        for (final match in regex.allMatches(content)) {
          imports.add(match.group(1)!);
        }
      }

      return imports;
    } catch (_) {
      return [];
    }
  }

  /// Find what depends on a given file (reverse dependency lookup)
  static Future<List<String>> findDependents(
      String projectName, String targetFile) async {
    final graph = await buildImportGraph(projectName);
    final dependents = <String>[];

    for (final entry in graph.entries) {
      for (final imp in entry.value) {
        if (imp.contains(targetFile.replaceAll(".ts", "")) ||
            imp.contains(targetFile.replaceAll(".py", "")) ||
            imp.contains(targetFile.replaceAll(".dart", ""))) {
          dependents.add(entry.key);
          break;
        }
      }
    }

    return dependents;
  }

  /// Impact analysis: if I change file X, what might break?
  static Future<ImpactAnalysis> analyzeImpact(
      String projectName, String targetFile) async {
    final dependents =
        await findDependents(projectName, targetFile);
    final transitiveEffects = <String>[];

    for (final dep in dependents) {
      final subDependents =
          await findDependents(projectName, dep);
      for (final sub in subDependents) {
        if (!transitiveEffects.contains(sub) &&
            !dependents.contains(sub) &&
            sub != targetFile) {
          transitiveEffects.add(sub);
        }
      }
    }

    return ImpactAnalysis(
      target: targetFile,
      directDependents: dependents,
      transitiveDependents: transitiveEffects,
      riskLevel: dependents.length > 5
          ? "HIGH"
          : dependents.length > 2
              ? "MEDIUM"
              : "LOW",
    );
  }

  /// Find code patterns similar to a given snippet
  static Future<List<PatternMatch>> findSimilarPatterns(
      String projectName, String pattern,
      {int maxResults = 10}) async {
    final results = <PatternMatch>[];
    final regex = RegExp(RegExp.escape(pattern),
        caseSensitive: false);

    Future<void> scanDir(String path) async {
      final entries =
          await StorageService.listDir(projectName, path);
      for (final entry in entries) {
        if (entry is Directory) {
          final name = entry.uri.pathSegments.last;
          if (name.startsWith(".") ||
              name == "node_modules" ||
              name == "dist") continue;
          await scanDir(
              path.isEmpty ? name : "$path/$name");
        } else if (entry is File) {
          final name = entry.uri.pathSegments.last;
          try {
            final content = await StorageService.readFile(
                projectName,
                path.isEmpty ? name : "$path/$name");
            if (regex.hasMatch(content)) {
              final match = regex.firstMatch(content)!;
              final lineNum = content
                  .substring(0, match.start)
                  .split("\n")
                  .length;
              results.add(PatternMatch(
                file: path.isEmpty ? name : "$path/$name",
                line: lineNum,
                snippet: content
                    .substring(
                        match.start > 20
                            ? match.start - 20
                            : 0,
                        match.end + 40 < content.length
                            ? match.end + 40
                            : content.length)
                    .trim(),
              ));
              if (results.length >= maxResults) return;
            }
          } catch (_) {}
        }
      }
    }

    await scanDir("");
    return results;
  }

  /// Generate code intelligence summary for agent context
  static Future<String> generateSummary(
      String projectName) async {
    final buffer = StringBuffer();
    buffer.writeln("\n## Code Intelligence");

    try {
      final graph = await buildImportGraph(projectName);
      buffer.writeln("Files analyzed: ${graph.length}");

      // Find most-imported files
      final importCounts = <String, int>{};
      for (final entry in graph.entries) {
        for (final imp in entry.value) {
          if (!imp.startsWith(".") && !imp.startsWith("@")) {
            importCounts[imp] =
                (importCounts[imp] ?? 0) + 1;
          }
        }
      }

      final sorted = importCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isNotEmpty) {
        buffer.write("Top dependencies: ");
        buffer.writeln(sorted
            .take(8)
            .map((e) => "${e.key} (${e.value}x)")
            .join(", "));
      }

      // Find entry points
      if (graph.containsKey("main.dart") ||
          graph.containsKey("main.ts") ||
          graph.containsKey("main.py") ||
          graph.containsKey("index.ts") ||
          graph.containsKey("index.js")) {
        buffer.writeln("Entry points found");
      }
    } catch (_) {
      buffer.writeln("(limited analysis available)");
    }

    return buffer.toString();
  }
}

class ImpactAnalysis {
  final String target;
  final List<String> directDependents;
  final List<String> transitiveDependents;
  final String riskLevel;

  ImpactAnalysis({
    required this.target,
    required this.directDependents,
    required this.transitiveDependents,
    required this.riskLevel,
  });
}

class PatternMatch {
  final String file;
  final int line;
  final String snippet;

  PatternMatch({
    required this.file,
    required this.line,
    required this.snippet,
  });
}
