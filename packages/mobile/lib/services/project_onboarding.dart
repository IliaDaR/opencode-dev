import "dart:convert";
import "dart:io";
import "storage_service.dart";
import "session_memory.dart";

/// Project onboarding — auto-summarize new repos for the agent
class ProjectOnboarding {
  /// Generate a comprehensive project summary
  static Future<String> summarize(String project) async {
    final buf = StringBuffer();
    buf.writeln("## Project Overview: $project\n");

    // Detect tech stack
    final stack = <String>[];
    try {
      final pkgJson =
          await StorageService.readFile(project, "package.json");
      final pkg = jsonDecode(pkgJson);
      final deps = pkg["dependencies"] as Map<String, dynamic>? ?? {};
      final devDeps =
          pkg["devDependencies"] as Map<String, dynamic>? ?? {};

      if (deps.containsKey("react") || deps.containsKey("next")) {
        stack.add("React/Next.js frontend");
      }
      if (deps.containsKey("solid-js")) stack.add("SolidJS");
      if (deps.containsKey("express")) stack.add("Express backend");
      if (deps.containsKey("fastify")) stack.add("Fastify backend");
      if (devDeps.containsKey("typescript")) stack.add("TypeScript");
      if (devDeps.containsKey("vitest")) stack.add("Vitest");
      if (devDeps.containsKey("jest")) stack.add("Jest");

      buf.writeln("### Tech Stack");
      buf.writeln(stack.isEmpty ? "Node.js project" : stack.join(", "));
      buf.writeln();

      // Key dependencies
      final allDeps = {...deps, ...devDeps};
      if (allDeps.isNotEmpty) {
        buf.writeln("### Key Dependencies");
        for (final e in allDeps.entries.take(10)) {
          buf.writeln("- ${e.key}: ${e.value}");
        }
        buf.writeln();
      }

      // Scripts
      final scripts = pkg["scripts"] as Map<String, dynamic>? ?? {};
      if (scripts.isNotEmpty) {
        buf.writeln("### Available Commands");
        for (final e in scripts.entries.take(10)) {
          buf.writeln("- `${e.key}`: `${e.value}`");
        }
        buf.writeln();
      }
    } catch (_) {
      // Not a Node.js project
    }

    // Python
    try {
      final pyproject =
          await StorageService.readFile(project, "pyproject.toml");
      stack.add("Python");
      buf.writeln("### Python project");
      buf.writeln("pyproject.toml found");
      buf.writeln();
    } catch (_) {}

    // README
    try {
      final readme =
          await StorageService.readFile(project, "README.md");
      final firstLines = readme.split("\n").take(5).join("\n");
      buf.writeln("### README Preview");
      buf.writeln(firstLines);
      buf.writeln();
    } catch (_) {
      buf.writeln("No README.md — consider adding one.\n");
    }

    // File structure
    try {
      final entries = await StorageService.listDir(project);
      buf.writeln("### Top-level Structure");
      for (final e in entries.take(20)) {
        final name = e.uri.pathSegments.last;
        if (name.startsWith(".")) continue;
        final icon = e is Directory ? "[DIR]" : "     ";
        buf.writeln("  $icon $name");
      }
    } catch (_) {}

    return buf.toString();
  }
}
