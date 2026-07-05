import "dart:convert";
import "dart:io";
import "storage_service.dart";

/// Check for outdated dependencies and suggest updates
class DependencyUpdater {
  /// Check npm dependencies for updates
  static Future<String> checkNpm(String project) async {
    try {
      final pkgJson =
          await StorageService.readFile(project, "package.json");
      final pkg = jsonDecode(pkgJson);
      final deps =
          pkg["dependencies"] as Map<String, dynamic>? ?? {};
      final devDeps =
          pkg["devDependencies"] as Map<String, dynamic>? ?? {};

      final buf = StringBuffer();
      buf.writeln("## Dependency Check\n");
      buf.writeln("Running npm outdated...\n");

      try {
        final result = await Process.run(
          "npm",
          ["outdated", "--json"],
          workingDirectory:
              "${StorageService.projectsRoot.path}/$project",
          runInShell: true,
        ).timeout(const Duration(seconds: 30));

        if (result.stdout.toString().isNotEmpty) {
          final outdated = jsonDecode(result.stdout.toString());
          for (final entry in outdated.entries) {
            final name = entry.key;
            final info = entry.value;
            buf.writeln(
                "- **$name**: ${info["current"]} → ${info["latest"]}");
            buf.writeln("  Type: ${info["type"]}");
          }
        } else {
          buf.writeln("✅ All dependencies up to date.");
        }
      } catch (_) {
        // npm outdated failed — list all deps with versions
        buf.writeln("Could not run npm. Installed dependencies:\n");
        buf.writeln("### Dependencies");
        for (final e in deps.entries.take(15)) {
          buf.writeln("- ${e.key}: ${e.value}");
        }
        if (devDeps.isNotEmpty) {
          buf.writeln("\n### Dev Dependencies");
          for (final e in devDeps.entries.take(15)) {
            buf.writeln("- ${e.key}: ${e.value}");
          }
        }
      }

      return buf.toString();
    } catch (e) {
      return "No package.json found. Not a Node.js project.";
    }
  }

  /// Check Python dependencies
  static Future<String> checkPython(String project) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? "pip" : "pip3",
        ["list", "--outdated", "--format=json"],
        workingDirectory:
            "${StorageService.projectsRoot.path}/$project",
        runInShell: true,
      ).timeout(const Duration(seconds: 30));

      if (result.stdout.toString().isNotEmpty) {
        final outdated = jsonDecode(result.stdout.toString());
        if (outdated is List && outdated.isEmpty) {
          return "✅ All Python packages up to date.";
        }
        final buf = StringBuffer();
        buf.writeln("## Outdated Python Packages\n");
        for (final pkg in outdated) {
          buf.writeln(
              "- **${pkg["name"]}**: ${pkg["version"]} → ${pkg["latest_version"]}");
        }
        return buf.toString();
      }
      return "✅ All Python packages up to date.";
    } catch (e) {
      return "Could not check Python packages. Is pip installed?";
    }
  }

  /// Auto-detect project type and check deps
  static Future<String> check(String project) async {
    // Try npm first
    try {
      await StorageService.readFile(project, "package.json");
      return await checkNpm(project);
    } catch (_) {}

    // Try Python
    try {
      await StorageService.readFile(project, "pyproject.toml");
      return await checkPython(project);
    } catch (_) {}

    return "No supported dependency manager found (npm/pip).";
  }
}
