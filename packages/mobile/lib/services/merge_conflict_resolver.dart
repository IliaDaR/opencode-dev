import "dart:io";
import "storage_service.dart";

/// Merge conflict detection and resolution
class MergeConflictResolver {
  /// Check if there are merge conflicts
  static Future<String> detect(String project) async {
    try {
      final result = await Process.run(
        "git",
        ["diff", "--name-only", "--diff-filter=U"],
        workingDirectory:
            "${StorageService.projectsRoot.path}/$project",
        runInShell: true,
      );

      final out = (result.stdout as String).trim();
      if (out.isEmpty) return "No merge conflicts detected.";

      final files = out.split("\n");
      final buf = StringBuffer();
      buf.writeln("## Merge Conflicts Detected\n");
      buf.writeln("Conflicted files: ${files.length}\n");

      for (final file in files.take(10)) {
        buf.writeln("### $file");
        try {
          final content =
              await StorageService.readFile(project, file);
          final lines = content.split("\n");
          var inOurs = false;
          var inTheirs = false;
          var ourLines = 0;
          var theirLines = 0;

          for (final line in lines) {
            if (line.startsWith("<<<<<<<")) inOurs = true;
            else if (line.startsWith("=======")) { inOurs = false; inTheirs = true; }
            else if (line.startsWith(">>>>>>>")) inTheirs = false;
            else if (inOurs) ourLines++;
            else if (inTheirs) theirLines++;
          }

          buf.writeln("- Ours: $ourLines lines");
          buf.writeln("- Theirs: $theirLines lines");
        } catch (_) {
          buf.writeln("- Cannot read file");
        }
        buf.writeln();
      }

      buf.writeln("### Resolution Strategy");
      buf.writeln("1. Read each conflicted file with read_file");
      buf.writeln("2. Decide which version to keep (ours/theirs/both)");
      buf.writeln("3. Use edit_file to resolve conflicts");
      buf.writeln("4. git add the resolved files");
      buf.writeln("5. git commit and push");

      return buf.toString();
    } catch (e) {
      return "Cannot detect conflicts. Is git available? Error: $e";
    }
  }

  /// Show the conflict markers in a file
  static Future<String> showConflict(
      String project, String filePath) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      if (!content.contains("<<<<<<<")) {
        return "No conflict markers found in $filePath.";
      }

      final lines = content.split("\n");
      final buf = StringBuffer();
      var inOurs = false;
      var inTheirs = false;

      buf.writeln("## Conflict in $filePath\n");

      for (final line in lines) {
        if (line.startsWith("<<<<<<<")) {
          inOurs = true;
          buf.writeln("=== OUR CHANGES ===");
        } else if (line.startsWith("=======")) {
          inOurs = false;
          inTheirs = true;
          buf.writeln("=== THEIR CHANGES ===");
        } else if (line.startsWith(">>>>>>>")) {
          inTheirs = false;
          buf.writeln("=== END CONFLICT ===\n");
        } else if (inOurs || inTheirs) {
          buf.writeln(line);
        }
      }

      return buf.toString();
    } catch (e) {
      return "Error: $e";
    }
  }
}
