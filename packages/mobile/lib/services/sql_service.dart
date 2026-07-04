import "dart:io";
import "storage_service.dart";

/// SQL database tools — run queries against project databases
class SqlService {
  /// Try to detect database files in the project
  static Future<String> detectDatabases(String project) async {
    final dbs = <String>[];
    try {
      final entries =
          await StorageService.listDir(project);
      for (final e in entries) {
        final name = e.uri.pathSegments.last;
        if (name.endsWith(".db") ||
            name.endsWith(".sqlite") ||
            name.endsWith(".sqlite3")) {
          dbs.add(name);
        }
      }
      return dbs.isEmpty
          ? "No SQLite databases found"
          : "Databases found: ${dbs.join(", ")}";
    } catch (e) {
      return "Error scanning: $e";
    }
  }

  /// Run SQLite query using system sqlite3 command
  static Future<String> runQuery(
      String project, String dbFile, String query) async {
    try {
      final dbPath =
          "${StorageService.projectsRoot.path}/$project/$dbFile";
      if (!await File(dbPath).exists()) {
        return "Database not found: $dbFile";
      }

      final result = await Process.run(
        Platform.isWindows ? "cmd" : "sh",
        [
          Platform.isWindows ? "/c" : "-c",
          "sqlite3 -header -column '$dbPath' \"$query\"",
        ],
        runInShell: true,
      );

      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();

      if (err.isNotEmpty && !err.contains("Warning")) {
        return "SQL error: $err";
      }

      return out.isEmpty ? "(empty result)" : out;
    } catch (e) {
      return "Query failed. Is sqlite3 installed? Error: $e";
    }
  }

  /// Show database schema
  static Future<String> showSchema(
      String project, String dbFile) async {
    final tables =
        await runQuery(project, dbFile, ".tables");
    if (tables.startsWith("SQL error") ||
        tables.startsWith("Query failed")) {
      return tables;
    }

    final buffer = StringBuffer();
    buffer.writeln("Tables: ${tables.trim()}");

    final tableNames = tables.trim().split(RegExp(r'\s+'));
    for (final table in tableNames.take(10)) {
      if (table.isEmpty) continue;
      final schema = await runQuery(
          project, dbFile, ".schema $table");
      buffer.writeln("\n$schema");
    }

    return buffer.toString();
  }

  /// Generate SQL from natural language
  static String generateSQLQuery(
      String description,
      List<Map<String, String>> tables) {
    final buffer = StringBuffer();
    buffer.writeln("## Schema Context");
    for (final t in tables) {
      buffer.writeln("Table: ${t["name"]}");
      buffer.writeln("  Columns: ${t["columns"]}");
      buffer.writeln();
    }
    buffer.writeln("## Task");
    buffer.writeln("Write an SQL query to: $description");
    buffer.writeln();
    buffer.writeln("Respond with the SQL query in a code block.");

    return buffer.toString();
  }
}
