import "dart:io";
import "storage_service.dart";

/// Generate production artifacts — tests, boilerplate, optimized code
class CodeGenerationService {
  /// Generate a test file template for a source file
  static Future<String> generateTestTemplate(
      String project, String sourceFile) async {
    try {
      final content =
          await StorageService.readFile(project, sourceFile);
      final ext = sourceFile.split(".").last;

      // Find exported functions
      final exports = <String>[];
      final exportRegex = RegExp(
          r'(?:export\s+(?:async\s+)?function|export\s+const)\s+(\w+)');
      for (final m in exportRegex.allMatches(content)) {
        exports.add(m.group(1)!);
      }

      // Find class methods
      final methodRegex = RegExp(r'(?:async\s+)?(\w+)\s*\([^)]*\)\s*{');
      for (final m in methodRegex.allMatches(content)) {
        final name = m.group(1)!;
        if (!["if", "for", "while", "switch", "catch", "constructor"]
            .contains(name)) {
          exports.add(name);
        }
      }

      final buf = StringBuffer();
      buf.writeln("// Generated test template for $sourceFile\n");

      if (ext == "ts" || ext == "tsx") {
        buf.writeln("import { describe, test, expect } from 'vitest';");
        buf.writeln("import { ${exports.join(', ')} } from './${sourceFile.split('/').last.replaceAll('.ts', '')}';\n");
        buf.writeln("describe('$sourceFile', () {");
        for (final fn in exports.take(10)) {
          buf.writeln("  test('$fn — happy path', () {");
          buf.writeln("    // Arrange");
          buf.writeln("    // Act");
          buf.writeln("    // Assert");
          buf.writeln("  });\n");
          buf.writeln("  test('$fn — handles edge cases', () {");
          buf.writeln("    // TODO: test null, empty, invalid input");
          buf.writeln("  });\n");
        }
        buf.writeln("});");
      } else if (ext == "py") {
        buf.writeln("import pytest");
        buf.writeln("from ${sourceFile.split('/').last.replaceAll('.py', '')} import ${exports.join(', ')}\n");
        for (final fn in exports.take(10)) {
          buf.writeln("def test_${fn}_happy_path():");
          buf.writeln("    # Arrange");
          buf.writeln("    # Act");
          buf.writeln("    # Assert");
          buf.writeln("    pass\n");
          buf.writeln("def test_${fn}_edge_cases():");
          buf.writeln("    pass\n");
        }
      }

      return buf.toString();
    } catch (e) {
      return "Cannot generate tests: $e";
    }
  }

  /// Generate project boilerplate
  static String generateBoilerplate(
      String projectType, String name) {
    switch (projectType) {
      case "express-api":
        return _expressBoilerplate(name);
      case "react-component":
        return _reactBoilerplate(name);
      case "python-fastapi":
        return _fastapiBoilerplate(name);
      case "flutter-screen":
        return _flutterBoilerplate(name);
      default:
        return "Unknown project type: $projectType";
    }
  }

  static String _expressBoilerplate(String name) {
    return '''
import express from 'express';

const app = express();
app.use(express.json());

app.get('/health', (_, res) => res.json({ status: 'ok' }));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(\`$name running on \$port\`));

export default app;
''';
  }

  static String _reactBoilerplate(String name) {
    return '''
import React from 'react';

interface ${name}Props {
  // Define props here
}

export function $name({}: ${name}Props) {
  return <div>$name</div>;
}
''';
  }

  static String _fastapiBoilerplate(String name) {
    return '''
from fastapi import FastAPI

app = FastAPI(title="$name")

@app.get("/health")
async def health():
    return {"status": "ok"}
''';
  }

  static String _flutterBoilerplate(String name) {
    return '''
import 'package:flutter/material.dart';

class $name extends StatelessWidget {
  const $name({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$name')),
      body: const Center(child: Text('$name')),
    );
  }
}
''';
  }

  /// Suggest optimizations for a code snippet
  static String suggestOptimizations(String code) {
    final suggestions = <String>[];

    // N+1 patterns
    if (RegExp(r'for\s*\(.*\)\s*{\s*await\s+fetch',
            caseSensitive: false)
        .hasMatch(code)) {
      suggestions.add("- 🔴 N+1 query pattern: loop contains async fetch. Use Promise.all or batch query.");
    }

    // Inefficient array operations
    if (RegExp(r'\.filter\(.*\)\.map\(.*\)\.filter\(.*\)')
        .hasMatch(code)) {
      suggestions.add("- ⚠️ Chained filter/map/filter — combine into single reduce or for loop.");
    }

    // Missing memo
    if (RegExp(r'\.sort\(|\.filter\(|\.map\(').hasMatch(code) &&
        RegExp(r'useMemo|useCallback').hasMatch(code) == false) {
      suggestions.add("- ℹ️ Array operations in render — consider useMemo.");
    }

    // Sync in async
    if (RegExp(r'async.*{[\s\S]*readFileSync|writeFileSync',
            caseSensitive: false)
        .hasMatch(code)) {
      suggestions.add("- ⚠️ Sync file operation inside async function. Use async version.");
    }

    // Large inline objects
    if (RegExp(r'{\s*\n\s*\w+:\s*\w+,\s*\n\s*\w+:\s*\w+,\s*\n').hasMatch(code)) {
      suggestions.add("- ℹ️ Inline object >2 properties. Extract to named constant or type.");
    }

    return suggestions.isEmpty
        ? "No optimization suggestions found."
        : suggestions.join("\n");
  }
}
