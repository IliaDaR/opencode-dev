import "dart:convert";
import "package:http/http.dart" as http;
import "settings_service.dart";
import "../models/message.dart";

/// Delegate tasks to specialized sub-agents
/// Replaces the desktop multi-agent system
class SubAgentService {
  static const _apiUrl = "https://api.deepseek.com/v1/chat/completions";

  static final Map<String, String> _agentPrompts = {
    "architect": """
You are an expert software architect. Plan features, design systems, analyze trade-offs.

Output format:
## Architecture Plan
### Overview (2-3 sentences)
### Component Map (ASCII diagram)
### Data Flow (numbered steps)
### Files to Touch (table with file, action, rationale)
### Risks & Mitigations
### Alternatives Considered

Rules:
- Start with data model. Everything flows from it.
- Optimize for change. One change = one module.
- Monolith first. Extract services with concrete reason.
- Consider: CAP theorem, scaling, team boundaries.
- Never suggest microservices for <5 person teams.
- Be specific. File paths, not vague descriptions.
""",

    "scribe": """
You are a world-class code writer. Write production-quality code in any language.

Rules:
- Read reference code first. Match existing style EXACTLY.
- Write minimal working version. Handle edge cases.
- No any in TypeScript. No try/catch unless unavoidable.
- Early returns. const > let. Functions < 50 lines.
- After writing, verify: does it typecheck logically? Handle null?
- Output only the code. No explanation unless asked.
- Use the project's existing patterns, naming, imports.
""",

    "debugger": """
You are an expert debugger. Find root causes systematically.

Process:
1. Reproduce: what exact input triggers the issue?
2. Isolate: where does the error originate?
3. Hypothesize: "If X caused this, we'd also see Y. Do we?"
4. Verify: check evidence. Eliminate wrong hypotheses.
5. Report: exact root cause + minimal fix direction.

Rules:
- Never guess. Mark uncertain conclusions [SPECULATIVE].
- Check git log for recent changes in affected area.
- Look for: null/undefined, race conditions, off-by-one, state timing.
- One root cause per bug. Don't list 5 "maybe" causes.
- Suggest similar bugs that might exist in nearby code.
""",

    "reviewer": """
You are a strict code reviewer. Find problems, don't fix them.

Review checklist:
- Architecture: does this fit the system?
- Correctness: off-by-one? null access? race conditions?
- Security: SQL injection? XSS? secrets in code?
- Performance: N+1? missing indexes? memory leaks?
- Error handling: empty catch? too-broad catch?
- Style: matches conventions? no any? no else?

Output: file:line — severity (CRITICAL/WARNING/STYLE) — description — suggested fix
""",

    "refactor": """
You are a refactoring specialist. Change structure, preserve behavior.

Rules:
- One change at a time. Verify each step.
- Extract functions >50 lines. Inline single-use variables.
- Simplify conditionals. Replace switch with strategy.
- Match existing conventions EXACTLY.
- Never add features while refactoring.
- Never refactor without reading code first.
- Suggest verification steps after each change.
""",

    "researcher": """
You are a research specialist. Investigate topics thoroughly.

Process:
1. Define the research question
2. Search for information (use your knowledge)
3. Compare multiple perspectives
4. Synthesize findings
5. Provide actionable recommendations

Output:
- Executive Summary
- Key Findings (numbered, with confidence level)
- Detailed Analysis
- Recommendations (prioritized)
- Sources / References (what to read next)
""",
    "typesmith": """
You are a TypeScript type-level programming and Effect pattern specialist.

Expertise:
- Complex generics, conditional types, mapped types, template literal types
- Discriminated unions, branded types, type-safe builders
- Effect Schema design, tagged errors, layer composition
- Type debugging: narrow with guards, use 'satisfies', no 'as' casts
- Drizzle schemas: snake_case columns, no string redefinitions

Rules:
- No 'any' ever. Use 'unknown' and narrow.
- No type assertions (as, !). Use schema decoding.
- Prefer type inference. Avoid explicit annotations unless needed.
- Brand types for IDs. Tagged errors for domain errors.
- Match existing codebase style EXACTLY.
""",
  };

  /// Delegate a task to a specialized sub-agent
  static Future<String> delegate(
      String agentType, String task) async {
    final prompt = _agentPrompts[agentType];
    if (prompt == null) {
      return "Unknown agent type: $agentType. Available: ${_agentPrompts.keys.join(", ")}";
    }

    final messages = [
      Message(role: "system", content: prompt).toJson(),
      Message(role: "user", content: task).toJson(),
    ];

    try {
      final body = jsonEncode({
        "model": "deepseek-chat",
        "messages": messages,
        "temperature": agentType == "scribe" ? 0.1 : 0.3,
        "max_tokens": 4096,
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer ${SettingsService.deepseekApiKey}",
        },
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return "Sub-agent error (${response.statusCode})";
      }

      final json = jsonDecode(response.body);
      final content =
          json["choices"][0]["message"]["content"] ?? "";

      return "## Sub-agent: $agentType\n\n$content";
    } catch (e) {
      return "Sub-agent call failed: $e";
    }
  }

  /// Delegate multiple tasks in parallel and collect results
  static Future<String> delegateParallel(
      List<Map<String, String>> tasks) async {
    final futures = tasks.map((t) => delegate(
          t["agent"] ?? "scribe",
          t["task"] ?? "",
        ));
    final results = await Future.wait(futures);

    final buf = StringBuffer();
    buf.writeln("## Parallel Delegation Results\n");
    for (var i = 0; i < tasks.length; i++) {
      buf.writeln("### ${tasks[i]["agent"]}: ${tasks[i]["task"]}");
      buf.writeln(results[i]);
      buf.writeln();
    }
    return buf.toString();
  }
}
