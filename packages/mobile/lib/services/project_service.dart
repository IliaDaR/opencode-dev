import "dart:io";
import "storage_service.dart";

/// Documentation generation and code explanation
class DocumentationService {
  /// Generate API documentation from source code
  static Future<String> generateApiDocs(
      String project, String sourceFile) async {
    try {
      final content =
          await StorageService.readFile(project, sourceFile);
      final buf = StringBuffer();
      buf.writeln("# API Documentation: $sourceFile\n");

      // Find exported functions
      final exportRegex = RegExp(
          r'export\s+(?:async\s+)?function\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*(\w+(?:<[^>]+>)?))?',
          multiLine: true);

      for (final m in exportRegex.allMatches(content)) {
        final name = m.group(1)!;
        final params = m.group(2) ?? "";
        final returnType = m.group(3) ?? "void";

        buf.writeln("## $name($params): $returnType");
        buf.writeln();

        // Find JSDoc comment above function
        final start = m.start;
        final before = content.substring(0 > start - 500 ? 0 : start - 500, start);
        final jsdocMatch = RegExp(
                r'/\*\*([\s\S]*?)\*/\s*$')
            .firstMatch(before);
        if (jsdocMatch != null) {
          buf.writeln(jsdocMatch.group(1)!
              .replaceAll(RegExp(r'^\s*\*\s?', multiLine: true), '')
              .trim());
          buf.writeln();
        }

        buf.writeln("### Parameters");
        if (params.trim().isEmpty) {
          buf.writeln("None");
        } else {
          for (final param in params.split(",")) {
            buf.writeln("- `${param.trim()}`");
          }
        }
        buf.writeln();
        buf.writeln("### Returns");
        buf.writeln("`$returnType`");
        buf.writeln();
      }

      // Find exported classes
      final classRegex = RegExp(
          r'export\s+class\s+(\w+)\s*(?:extends\s+(\w+))?\s*{',
          multiLine: true);
      for (final m in classRegex.allMatches(content)) {
        final name = m.group(1)!;
        final parent = m.group(2);
        buf.writeln("## Class: $name");
        if (parent != null) buf.writeln("Extends: $parent");
        buf.writeln();
      }

      return buf.toString();
    } catch (e) {
      return "Cannot generate docs: $e";
    }
  }

  /// Generate CHANGELOG from git log
  static String generateChangelog(List<String> commits) {
    final buf = StringBuffer();
    buf.writeln("# Changelog\n");

    final grouped = <String, List<String>>{
      "Features": [],
      "Fixes": [],
      "Docs": [],
      "Chores": [],
      "Refactors": [],
    };

    for (final commit in commits) {
      final lower = commit.toLowerCase();
      if (lower.startsWith("feat")) {
        grouped["Features"]!.add(commit);
      } else if (lower.startsWith("fix")) {
        grouped["Fixes"]!.add(commit);
      } else if (lower.startsWith("docs")) {
        grouped["Docs"]!.add(commit);
      } else if (lower.startsWith("chore")) {
        grouped["Chores"]!.add(commit);
      } else if (lower.startsWith("refactor")) {
        grouped["Refactors"]!.add(commit);
      }
    }

    for (final entry in grouped.entries) {
      if (entry.value.isNotEmpty) {
        buf.writeln("## ${entry.key}");
        for (final c in entry.value) {
          buf.writeln("- $c");
        }
        buf.writeln();
      }
    }

    return buf.toString();
  }

  /// Estimate effort for a task
  static String estimateEffort(String description) {
    final lower = description.toLowerCase();
    final factors = <String, int>{};

    if (lower.contains("new") && lower.contains("feature")) {
      factors["New feature"] = 5;
    }
    if (lower.contains("fix") || lower.contains("bug")) {
      factors["Bug fix"] = 1;
    }
    if (lower.contains("refactor")) {
      factors["Refactoring"] = 3;
    }
    if (lower.contains("api") || lower.contains("endpoint")) {
      factors["API work"] = 3;
    }
    if (lower.contains("database") || lower.contains("migration")) {
      factors["Database changes"] = 4;
    }
    if (lower.contains("ui") || lower.contains("component") || lower.contains("frontend")) {
      factors["UI/Frontend"] = 3;
    }
    if (lower.contains("test")) {
      factors["Testing"] = 2;
    }
    if (lower.contains("documentation") || lower.contains("docs")) {
      factors["Documentation"] = 1;
    }
    if (lower.contains("auth")) {
      factors["Authentication"] = 4;
    }
    if (lower.contains("deploy") || lower.contains("ci") || lower.contains("cd")) {
      factors["DevOps/CI"] = 2;
    }

    if (factors.isEmpty) {
      return "## Effort Estimate\n\nInsufficient information. Please describe: what to build, what changes are needed, any constraints.";
    }

    var total = 0;
    final buf = StringBuffer();
    buf.writeln("## Effort Estimate\n");

    // Complexity levels: 1=trivial(1h), 2=easy(2-4h), 3=medium(1d), 5=complex(2-3d), 8=large(1w)
    const levels = {1: "1 hour", 2: "2-4 hours", 3: "1 day", 4: "2-3 days", 5: "3-5 days", 8: "1-2 weeks"};

    for (final entry in factors.entries) {
      final hours = levels[entry.value] ?? "unknown";
      buf.writeln("- ${entry.key}: $hours");
      total += entry.value;
    }

    final totalHours = levels[total > 8 ? 8 : total] ?? "${total} days";
    buf.writeln("\n**Total estimate: $totalHours**");
    buf.writeln("\n*This is a rough estimate. Actual time depends on codebase complexity, testing needs, and team experience.*");

    return buf.toString();
  }

  /// Generate README template
  static String generateReadmeTemplate(
      String projectName, String description, String techStack) {
    return '''
# $projectName

$description

## Quick Start

\`\`\`bash
git clone <repo>
cd $projectName
# Install dependencies
# Run setup
\`\`\`

## Tech Stack

$techStack

## Architecture

<!-- Describe your architecture here -->

## Development

\`\`\`bash
# Start dev server

# Run tests

# Run lint
\`\`\`

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| PORT | No | 3000 | Server port |

## Deployment

<!-- Deployment instructions -->

## License

MIT
''';
  }
}
