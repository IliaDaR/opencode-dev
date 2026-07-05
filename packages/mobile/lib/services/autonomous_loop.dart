import "dart:convert";
import "dart:io";
import "storage_service.dart";

/// Autonomous multi-step task execution
/// Agent plans → implements → reviews → fixes → commits without user intervention
class AutonomousLoop {
  /// Run an autonomous workflow: code → review → fix → commit
  /// Only stops and asks user when truly blocked
  static String get systemPrompt => """
## AUTONOMOUS MODE

When working autonomously, follow this loop without asking the user:

1. PLAN: Read files, understand context, create mental plan
2. IMPLEMENT: Write/edit code. One file at a time.
3. REVIEW: After each file, run quick mental check:
   - Did I handle null/empty/edge cases?
   - Do imports reference real files?
   - Is the style consistent with the rest of the project?
4. FIX: If you find issues, fix them. Don't ask — just fix.
5. COMMIT: Use git_sync with meaningful message. Format: type(scope): description
6. REPORT: Brief summary: "Done: [what]. Changed: [files]."

### When to STOP and ask user:
- Architecture decision that changes project structure
- Need to choose between two valid approaches
- External dependency that requires user's account/credentials
- Task is complete and you're not sure what to do next

### Never stop for:
- Style questions (follow existing code)
- Implementation details
- Error recovery (try alternative approach first)
- Confirmation before committing (commit unless destructive)

### Self-correction:
If a tool call fails, analyze the error and try a different approach.
If edit_file fails, read_file first to get exact text.
If write_file fails, check the directory exists.
If run_command fails, check if the tool is installed.
""";

  /// Record autonomous execution result
  static Future<void> recordExecution(
      String project, Map<String, dynamic> result) async {
    try {
      final path = ".opencode/autonomous-log.json";
      List<Map<String, dynamic>> log;
      try {
        final existing =
            await StorageService.readFile(project, path);
        log = (jsonDecode(existing) as List)
            .cast<Map<String, dynamic>>();
      } catch (_) {
        log = [];
      }

      log.add({
        "timestamp": DateTime.now().toIso8601String(),
        ...result,
      });

      if (log.length > 50) log.removeAt(0);
      await StorageService.writeFile(
          project, path, jsonEncode(log));
    } catch (_) {}
  }

  /// Check if agent is stuck in a loop
  static Future<bool> isStuck(String project) async {
    try {
      final path = ".opencode/autonomous-log.json";
      final existing =
          await StorageService.readFile(project, path);
      final log = (jsonDecode(existing) as List)
          .cast<Map<String, dynamic>>();

      if (log.length < 3) return false;

      // Check last 3 entries for repeated failures
      final last3 = log.sublist(log.length - 3);
      final allFailed =
          last3.every((e) => e["success"] == false);
      return allFailed;
    } catch (_) {
      return false;
    }
  }
}
