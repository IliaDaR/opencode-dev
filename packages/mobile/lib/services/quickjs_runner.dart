/// QuickJS plugin runner — executes JavaScript plugins on Android
/// Replace Node.js-based .ts plugins with JavaScript running on QuickJS engine
/// To enable: add `flutter_js: ^0.8.0` to pubspec.yaml
/// Then: `import "package:flutter_js/flutter_js.dart";`
///
/// Usage:
///   final runner = QuickJsRunner();
///   await runner.init();
///   final result = await runner.eval("1 + 1"); // "2"
///   await runner.eval(pluginSourceCode);
class QuickJsRunner {
  // On setup:
  // final _js = getJavascriptRuntime();
  // await _js.evaluate("const console = { log: (msg) => {} };");

  /// Convert a TypeScript plugin (.ts file) to runnable JavaScript
  /// Strips type annotations, keeps the logic
  static String tsToJs(String tsCode) {
    return tsCode
        .replaceAll(RegExp(r":\s*\w+(\[\])?\s*[=;,)]"), "")
        .replaceAll(RegExp(r"interface\s+\w+\s*\{[^}]*\}"), "")
        .replaceAll(RegExp(r"type\s+\w+\s*=.*?;"), "")
        .replaceAll(RegExp(r"export\s+default\s+"), "const tool = ")
        .replaceAll(RegExp(r"import\s+.*?from\s+['\"].*?['\"]\s*;?"), "");
  }

  /// Built-in tools that can be loaded as plugins
  static const Map<String, String> builtInPlugins = {
    "code-review": """
      const review = (code) => {
        const issues = [];
        if (code.includes('any')) issues.push('Avoid any type');
        if (code.includes('console.log')) issues.push('Use proper logger');
        if (code.includes('==') && !code.includes('===')) issues.push('Use === not ==');
        return issues;
      };
    """,
    "git-helper": """
      const parseGitLog = (log) => {
        return log.split('\\n').filter(l => l).map(l => ({
          hash: l.substring(0, 7),
          message: l.substring(8)
        }));
      };
    """,
  };
}
