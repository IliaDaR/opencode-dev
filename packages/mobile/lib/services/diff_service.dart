import "dart:io";
import "storage_service.dart";

/// Generate diffs between file versions for preview before applying changes
class DiffService {
  /// Generate unified diff between two strings
  static String unifiedDiff(String oldText, String newText,
      {String? fileName, int contextLines = 3}) {
    final oldLines = oldText.split("\n");
    final newLines = newText.split("\n");
    final buf = StringBuffer();

    if (fileName != null) {
      buf.writeln("--- a/$fileName");
      buf.writeln("+++ b/$fileName");
    }

    // Simple LCS-based diff
    final lcs = _lcsMatrix(oldLines, newLines);
    final hunks = _buildHunks(oldLines, newLines, lcs, contextLines);

    for (final hunk in hunks) {
      buf.write(hunk);
    }

    return buf.toString();
  }

  static List<List<int>> _lcsMatrix(
      List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(
        m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] =
              dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }
    return dp;
  }

  static List<String> _buildHunks(List<String> oldLines,
      List<String> newLines, List<List<int>> dp, int ctx) {
    final hunks = <String>[];
    final changes = <int>[];
    var i = oldLines.length;
    var j = newLines.length;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        changes.add(j - 1);
        j--;
      } else {
        changes.add(-(i)); // negative = deletion index
        i--;
      }
    }

    // Build hunks with context
    final buf = StringBuffer();
    var hunkStart = -1;
    var oldStart = 0;
    var newStart = 0;
    var oldCount = 0;
    var newCount = 0;
    final hunkLines = <String>[];

    for (var idx = 0; idx < oldLines.length || idx < newLines.length; idx++) {
      if (idx < oldLines.length && idx < newLines.length &&
          oldLines[idx] == newLines[idx]) {
        if (hunkLines.isNotEmpty) {
          hunkLines.add(" ${oldLines[idx]}");
        }
      } else {
        if (hunkStart < 0) hunkStart = idx;
        if (idx < oldLines.length) {
          hunkLines.add("-${oldLines[idx]}");
          oldCount++;
        }
        if (idx < newLines.length &&
            (idx >= oldLines.length || oldLines[idx] != newLines[idx])) {
          hunkLines.add("+${newLines[idx]}");
          newCount++;
        }
      }
    }

    if (hunkLines.isNotEmpty) {
      buf.writeln(
          "@@ -${hunkStart + 1},$oldCount +${hunkStart + 1},$newCount @@");
      for (final line in hunkLines.take(50)) {
        buf.writeln(line);
      }
      if (hunkLines.length > 50) {
        buf.writeln("... (${hunkLines.length - 50} more lines)");
      }
    }

    return [buf.toString()];
  }

  /// Preview what would change in a file before applying edit
  static Future<String> previewEdit(
      String project, String filePath, String oldStr, String newStr) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      final updated = content.replaceFirst(oldStr, newStr);
      return unifiedDiff(content, updated,
          fileName: filePath);
    } catch (e) {
      return "Cannot preview: $e";
    }
  }

  /// Show diff of all uncommitted changes
  static Future<String> gitDiff(String project) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? "cmd" : "sh",
        [
          Platform.isWindows ? "/c" : "-c",
          "git diff",
        ],
        workingDirectory:
            "${StorageService.projectsRoot.path}/$project",
        runInShell: true,
      );
      final out = (result.stdout as String).trim();
      return out.isEmpty ? "No changes" : out;
    } catch (e) {
      return "Cannot diff: $e";
    }
  }
}
