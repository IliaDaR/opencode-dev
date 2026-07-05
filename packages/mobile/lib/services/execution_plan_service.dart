/// Execution plan — for complex tasks, create a plan before acting
/// Simulates Claude Code's "thinking before doing" approach
class ExecutionPlanService {
  /// Analyze a task and create a step-by-step plan
  static String createPlan(String task, Map<String, dynamic> context) {
    final buf = StringBuffer();
    buf.writeln("## Execution Plan\n");
    buf.writeln("**Goal:** $task\n");

    // Step 1: Understand
    buf.writeln("### Phase 1: Understand");
    buf.writeln("- [ ] Read relevant files to understand current state");
    buf.writeln("- [ ] Search for similar patterns in the codebase");
    buf.writeln("- [ ] Check imports and dependencies");
    buf.writeln();

    // Step 2: Design
    buf.writeln("### Phase 2: Design");
    buf.writeln("- [ ] Plan file changes (which files, what changes)");
    buf.writeln("- [ ] Consider edge cases and error handling");
    buf.writeln("- [ ] Check impact analysis — what else might break?");
    buf.writeln();

    // Step 3: Implement
    buf.writeln("### Phase 3: Implement");
    buf.writeln("- [ ] Make changes one file at a time");
    buf.writeln("- [ ] Use edit_file for existing files, write_file for new files");
    buf.writeln("- [ ] Verify each change with diagnose_file");
    buf.writeln();

    // Step 4: Verify
    buf.writeln("### Phase 4: Verify");
    buf.writeln("- [ ] Run tests if available (run_command)");
    buf.writeln("- [ ] Check imports (check_imports)");
    buf.writeln("- [ ] Format code (format_code)");
    buf.writeln("- [ ] Review diff before committing");
    buf.writeln();

    // Step 5: Commit
    buf.writeln("### Phase 5: Commit");
    buf.writeln("- [ ] Use git_sync with meaningful commit message");
    buf.writeln("- [ ] Format: type(scope): description");
    buf.writeln();

    return buf.toString();
  }

  /// Generate a checklist for the agent to follow
  static String generateChecklist(List<String> steps) {
    final buf = StringBuffer();
    buf.writeln("## Task Checklist\n");
    for (var i = 0; i < steps.length; i++) {
      buf.writeln("- [ ] ${i + 1}. ${steps[i]}");
    }
    return buf.toString();
  }

  /// Auto-detect if a task is complex enough to need a plan
  static bool needsPlan(String task) {
    final lower = task.toLowerCase();
    final complexIndicators = [
      "implement", "build", "create", "refactor",
      "migrate", "redesign", "restructure", "add feature",
      "fix all", "optimize", "set up", "configure",
    ];
    final simpleIndicators = [
      "what is", "explain", "how to", "show me",
      "find", "read", "list", "check",
    ];

    final complex =
        complexIndicators.any((i) => lower.contains(i));
    final simple =
        simpleIndicators.any((i) => lower.contains(i)) && !complex;

    return complex && !simple;
  }
}
