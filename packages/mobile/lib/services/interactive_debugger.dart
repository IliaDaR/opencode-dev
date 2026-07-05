import "dart:io";
import "storage_service.dart";

/// Interactive debug simulator — uses LLM to trace through code
class InteractiveDebugger {
  /// Simulate stepping through code with breakpoints
  static String addBreakpoint(String filePath, int line) {
    return """
## Breakpoint at $filePath:$line

I'll help you debug. What would you like to know about the state at this line?

Available commands:
- `values` — list all variables and their types at this point
- `trace` — show call stack leading to this line
- `watch <var>` — watch a specific variable
- `step` — execute next line
- `continue` — resume execution
""";
  }

  /// Analyze a function for potential bugs
  static Future<String> analyzeFunction(
      String project, String filePath, String functionName) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      final buf = StringBuffer();
      buf.writeln("## Function Analysis: $functionName\n");

      // Find function boundaries
      final funcRegex = RegExp(
          '(?:function|def|async function|export function|void|Future<\\w+>)\\s+$functionName\\s*\\([^)]*\\)\\s*\\{?');
      final match = funcRegex.firstMatch(content);

      if (match == null) {
        return "Function '$functionName' not found in $filePath.";
      }

      final start = match.start;
      var depth = 0;
      var end = match.end;
      var inFunc = false;

      for (var i = match.end; i < content.length; i++) {
        if (content[i] == '{') { depth++; inFunc = true; }
        if (content[i] == '}') { depth--; }
        if (inFunc && depth == 0) { end = i + 1; break; }
      }

      final funcBody = content.substring(start, end);

      // Analyze
      buf.writeln("### Returns");
      final returnRegex =
          RegExp(r'return\s+(.+?);', multiLine: true);
      for (final m in returnRegex.allMatches(funcBody)) {
        buf.writeln("- Returns: `${m.group(1)}`");
      }

      buf.writeln("\n### Variables");
      final varRegex = RegExp(
          r'(?:const|let|var|final)\s+(\w+)\s*[=:]');
      final vars = <String>{};
      for (final m in varRegex.allMatches(funcBody)) {
        vars.add(m.group(1)!);
      }
      if (vars.isNotEmpty) {
        buf.writeln(vars.map((v) => "- `$v`").join("\n"));
      }

      buf.writeln("\n### Potential Issues");
      if (funcBody.contains("any") && filePath.endsWith(".ts")) {
        buf.writeln("- ⚠️ Uses 'any' type");
      }
      if (RegExp(r'\.then\(').hasMatch(funcBody) &&
          !RegExp(r'await').hasMatch(funcBody)) {
        buf.writeln("- ⚠️ Promise chain without async/await");
      }
      if (funcBody.split("\n").length > 50) {
        buf.writeln("- ℹ️ Function is ${funcBody.split("\n").length} lines — consider splitting");
      }
      if (!RegExp(r'try\s*\{|catch\s*\(').hasMatch(funcBody) &&
          RegExp(r'await|fetch|readFile|writeFile').hasMatch(funcBody)) {
        buf.writeln("- ℹ️ No error handling for async operations");
      }

      return buf.toString();
    } catch (e) {
      return "Cannot analyze: $e";
    }
  }
}
