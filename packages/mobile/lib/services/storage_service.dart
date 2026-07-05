import "dart:io";
import "package:path_provider/path_provider.dart";
import "package:path/path.dart" as p;

class StorageService {
  static late Directory _projectsRoot;

  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _projectsRoot =
        Directory(p.join(appDir.path, "opencode-projects"));
    if (!await _projectsRoot.exists()) {
      await _projectsRoot.create(recursive: true);
    }
  }

  static Directory get projectsRoot {
    return _projectsRoot;
  }

  static Directory projectDir(String name) {
    return Directory(p.join(_projectsRoot.path, name));
  }

  static Future<bool> projectExists(String name) async {
    return await projectDir(name).exists();
  }

  static Future<List<String>> listProjects() async {
    final entries = await _projectsRoot.list().toList();
    return entries
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
  }

  static File _safeFile(String project, String filePath) {
    final fullPath = p.join(_projectsRoot.path, project, filePath);
    final normalized = p.normalize(fullPath);
    if (!normalized.startsWith(p.normalize(_projectsRoot.path))) {
      throw Exception("Path traversal detected: $filePath");
    }
    return File(fullPath);
  }

  static Directory _safeDir(String project, String subPath) {
    final fullPath = p.join(_projectsRoot.path, project, subPath);
    final normalized = p.normalize(fullPath);
    if (!normalized.startsWith(p.normalize(_projectsRoot.path))) {
      throw Exception("Path traversal detected: $subPath");
    }
    return Directory(fullPath);
  }

  static Future<String> readFile(
      String project, String filePath) async {
    final file = _safeFile(project, filePath);
    return await file.readAsString();
  }

  static Future<void> writeFile(
      String project, String filePath, String content) async {
    final file = _safeFile(project, filePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  static Future<void> deleteFile(
      String project, String filePath) async {
    final file = _safeFile(project, filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<List<FileSystemEntity>> listDir(String project,
      [String subPath = ""]) async {
    final dir = _safeDir(project, subPath);
    if (!await dir.exists()) {
      return [];
    }
    return await dir.list().toList();
  }

  static Future<List<String>> searchCode(String project,
      String pattern,
      [String? fileExt]) async {
    final results = <String>[];
    final regex = RegExp(pattern, caseSensitive: false);

    Future<void> searchDir(String subPath) async {
      final entries = await listDir(project, subPath);
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (name.startsWith(".")) {
          continue;
        }

        if (entry is Directory) {
          await searchDir(
              subPath.isEmpty ? name : "$subPath/$name");
        } else if (entry is File) {
          if (fileExt != null && !name.endsWith(fileExt)) {
            continue;
          }
          try {
            final lines = await entry.readAsLines();
            for (var i = 0; i < lines.length; i++) {
              if (regex.hasMatch(lines[i])) {
                final relPath =
                    subPath.isEmpty ? name : "$subPath/$name";
                results.add(
                    "$relPath:${i + 1}: ${lines[i].trim()}");
                if (results.length >= 30) {
                  return;
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    await searchDir("");
    return results;
  }
}
