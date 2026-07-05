import "storage_service.dart";

/// Pre-built code index for fast searches
/// Scans project on open, builds searchable index
class CodeIndex {
  final Map<String, String> _fileContents = {};
  final Map<String, List<String>> _symbolIndex = {};
  final Map<String, String> _importIndex = {};
  bool _indexed = false;

  bool get isIndexed => _indexed;

  /// Build index from project files
  Future<void> build(String project) async {
    _fileContents.clear();
    _symbolIndex.clear();
    _importIndex.clear();
    _indexed = false;

    await _scanDir(project, "");
    _indexed = true;
  }

  Future<void> _scanDir(String project, String path) async {
    final entries = await StorageService.listDir(project, path);
    for (final e in entries) {
      final name = e.uri.pathSegments.last;
      final fullPath = path.isEmpty ? name : "$path/$name";

      if (e is Directory) {
        if (name.startsWith(".") || name == "node_modules" || name == "dist") continue;
        await _scanDir(project, fullPath);
      } else {
        final ext = name.split(".").last;
        if (!["ts","tsx","js","jsx","py","dart","rs","go","java","kt","swift"]
            .contains(ext)) continue;

        try {
          final content = await StorageService.readFile(project, fullPath);
          _fileContents[fullPath] = content;

          // Index symbols (functions, classes, exports)
          final symbols = _extractSymbols(content, ext);
          for (final s in symbols) {
            _symbolIndex.putIfAbsent(s, () => []).add(fullPath);
          }

          // Index imports
          final imports = _extractImports(content, ext);
          for (final imp in imports) {
            _importIndex[imp] = fullPath;
          }
        } catch (_) {}
      }
    }
  }

  List<String> _extractSymbols(String content, String ext) {
    final symbols = <String>[];
    final patterns = {
      "ts": [RegExp(r'(?:export\s+(?:async\s+)?function|export\s+const|export\s+class|export\s+interface)\s+(\w+)')],
      "py": [RegExp(r'^def\s+(\w+)', multiLine: true), RegExp(r'^class\s+(\w+)', multiLine: true)],
      "dart": [RegExp(r'(?:class|mixin|enum)\s+(\w+)'), RegExp(r'(?:void|Future|Widget|String|int|bool)\s+(\w+)\s*\(')],
    };

    for (final pattern in (patterns[ext] ?? <RegExp>[])) {
      for (final m in pattern.allMatches(content)) {
        final name = m.group(1);
        if (name != null && name.length > 1) symbols.add(name);
      }
    }
    return symbols.take(100).toList();
  }

  List<String> _extractImports(String content, String ext) {
    final imports = <String>[];
    final pattern = RegExp(r'''import\s+.*?\s+from\s+['"]([^'"]+)['"]''');
    for (final m in pattern.allMatches(content)) {
      imports.add(m.group(1)!);
    }
    return imports.take(50).toList();
  }

  /// Search index for a symbol
  List<String> findSymbol(String name) {
    return _symbolIndex[name] ?? [];
  }

  /// Find which files import a given module
  List<String> findImporters(String modulePath) {
    return _fileContents.keys
        .where((f) => _importIndex[f] == modulePath)
        .toList();
  }

  /// Get file count
  int get fileCount => _fileContents.length;

  /// Get symbol count
  int get symbolCount => _symbolIndex.length;
}
