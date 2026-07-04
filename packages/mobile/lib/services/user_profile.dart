import "dart:convert";
import "dart:io";
import "storage_service.dart";

/// Learns and persists user preferences over time.
/// Automatically extracts coding style, naming conventions,
/// and tech preferences from the user's interactions and projects.
class UserProfile {
  static String get _path {
    return "${StorageService.projectsRoot.path}/../opencode-profile.json";
  }

  static Future<Map<String, dynamic>> _load() async {
    final file = File(_path);
    if (!await file.exists()) return _defaultProfile();
    try {
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return _defaultProfile();
    }
  }

  static Future<void> _save(Map<String, dynamic> profile) async {
    await File(_path).writeAsString(
        const JsonEncoder.withIndent("  ").convert(profile));
  }

  static Map<String, dynamic> _defaultProfile() => {
        "coding_style": {
          "indent": "spaces", // spaces | tabs
          "indent_size": 2,
          "quotes": "double", // double | single
          "semicolons": true,
          "max_line_length": 100,
        },
        "tech_preferences": {
          "languages": <String>[],
          "frameworks": <String>[],
          "libraries": <String, int>{}, // name → usage count
          "avoid": <String>[], // technologies to avoid
        },
        "naming": {
          "files": "kebab-case", // kebab-case | camelCase | PascalCase
          "functions": "camelCase",
          "classes": "PascalCase",
          "variables": "camelCase",
        },
        "patterns": {
          "error_handling": "exceptions", // exceptions | result-types | error-codes
          "state_management": "", // redux | zustand | context | mobx
          "architecture": "", // mvc | mvvm | clean | feature-based
          "testing": "", // jest | pytest | vitest | bun
        },
        "project_count": 0,
        "total_sessions": 0,
      };

  /// Get the full profile
  static Future<Map<String, dynamic>> getProfile() async {
    return await _load();
  }

  /// Record that user used a specific technology
  static Future<void> learnTechnology(String name) async {
    final profile = await _load();
    final libs =
        profile["tech_preferences"]["libraries"] as Map<String, dynamic>;
    libs[name] = (libs[name] ?? 0) + 1;
    await _save(profile);
  }

  /// Record that user prefers a specific language/framework
  static Future<void> learnLanguage(String language) async {
    final profile = await _load();
    final langs =
        profile["tech_preferences"]["languages"] as List<dynamic>;
    if (!langs.contains(language)) {
      langs.add(language);
      if (langs.length > 10) langs.removeAt(0);
    }
    await _save(profile);
  }

  /// Learn from project analysis — detect conventions automatically
  static Future<void> learnFromProject(String projectName) async {
    final profile = await _load();
    profile["project_count"] = (profile["project_count"] ?? 0) + 1;

    try {
      final packageJson = await StorageService.readFile(
          projectName, "package.json");
      final pkg = jsonDecode(packageJson);
      final deps = pkg["dependencies"] as Map<String, dynamic>? ?? {};
      final devDeps =
          pkg["devDependencies"] as Map<String, dynamic>? ?? {};

      for (final dep in [...deps.keys, ...devDeps.keys]) {
        await learnTechnology(dep);
      }

      if (deps.containsKey("react") || deps.containsKey("next")) {
        await learnLanguage("JavaScript/TypeScript");
      }
      if (deps.containsKey("solid-js")) {
        await learnLanguage("SolidJS");
      }
      if (devDeps.containsKey("typescript")) {
        await learnLanguage("TypeScript");
      }
    } catch (_) {}

    try {
      final pyproject = await StorageService.readFile(
          projectName, "pyproject.toml");
      await learnLanguage("Python");
    } catch (_) {}

    await _save(profile);
  }

  /// Record a coding style preference
  static Future<void> setPreference(
      String category, String key, dynamic value) async {
    final profile = await _load();
    profile[category][key] = value;
    await _save(profile);
  }

  /// Generate a context injection for the agent
  static Future<String> toContextPrompt() async {
    final profile = await _load();
    final buffer = StringBuffer();
    buffer.writeln("\n## User Profile (learned over time)");

    final style = profile["coding_style"] as Map<String, dynamic>;
    buffer.writeln("Coding style: ${style["indent_size"]}-${style["indent"]}, ${style["quotes"]} quotes");

    final tech = profile["tech_preferences"] as Map<String, dynamic>;
    final langs = tech["languages"] as List<dynamic>;
    if (langs.isNotEmpty) {
      buffer.writeln("Languages: ${langs.join(", ")}");
    }

    final libs = tech["libraries"] as Map<String, dynamic>;
    if (libs.isNotEmpty) {
      final top = libs.entries.toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));
      final topNames =
          top.take(5).map((e) => e.key).join(", ");
      buffer.writeln("Top libraries: $topNames");
    }

    final avoid = tech["avoid"] as List<dynamic>;
    if (avoid.isNotEmpty) {
      buffer.writeln("Avoid: ${avoid.join(", ")}");
    }

    final patterns = profile["patterns"] as Map<String, dynamic>;
    if (patterns["architecture"] != null &&
        (patterns["architecture"] as String).isNotEmpty) {
      buffer.writeln(
          "Architecture: ${patterns["architecture"]}");
    }

    buffer.writeln(
        "Sessions: ${profile["total_sessions"]}, Projects: ${profile["project_count"]}");

    return buffer.toString();
  }

  /// Increment session counter
  static Future<void> recordSession() async {
    final profile = await _load();
    profile["total_sessions"] =
        (profile["total_sessions"] ?? 0) + 1;
    await _save(profile);
  }
}
