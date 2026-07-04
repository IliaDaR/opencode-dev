import "dart:convert";
import "dart:io";
import "package:http/http.dart" as http;
import "storage_service.dart";
import "git_service.dart";
import "skills.dart";
import "session_memory.dart";
import "research_service.dart";
import "user_profile.dart";
import "code_intelligence.dart";
import "../models/message.dart";
import "settings_service.dart";

enum AgentMode {
  auto,
  brainstorm,
  architect,
  code,
  debug,
  refactor,
  research,
}

class ProjectContext {
  final List<String> files;
  final Map<String, String> configFiles;
  final String structure;

  ProjectContext({
    required this.files,
    required this.configFiles,
    required this.structure,
  });
}

class AgentService {
  static const String _apiUrl =
      "https://api.deepseek.com/v1/chat/completions";

  final String projectName;
  GitService? gitService;
  final List<Message> messages = [];
  AgentMode currentMode = AgentMode.auto;
  ProjectContext? projectContext;

  AgentService({required this.projectName});

  void setGitService(GitService gs) {
    gitService = gs;
  }

  Future<void> scanProject() async {
    try {
      final entries = await StorageService.listDir(projectName);
      final files = <String>[];
      final configFiles = <String, String>{};

      for (final e in entries) {
        final name = e.uri.pathSegments.last;
        if (name.startsWith(".") && name != ".gitignore") continue;
        files.add(name);
      }

      final configNames = [
        "package.json",
        "tsconfig.json",
        "pyproject.toml",
        "Cargo.toml",
        "go.mod",
        "requirements.txt",
        "Dockerfile",
        "README.md",
        "AGENTS.md",
        ".gitignore",
      ];

      for (final name in configNames) {
        try {
          final content =
              await StorageService.readFile(projectName, name);
          configFiles[name] = content.length > 2000
              ? content.substring(0, 2000)
              : content;
        } catch (_) {}
      }

      final buffer = StringBuffer();
      buffer.writeln("Project: $projectName");
      buffer.writeln("Files: ${files.length} items");
      if (configFiles.containsKey("package.json")) {
        buffer.writeln("Type: Node.js/TypeScript project");
      }
      if (configFiles.containsKey("pyproject.toml") ||
          configFiles.containsKey("requirements.txt")) {
        buffer.writeln("Type: Python project");
      }
      if (configFiles.containsKey("Dockerfile")) {
        buffer.writeln("Docker: yes");
      }

      projectContext = ProjectContext(
        files: files,
        configFiles: configFiles,
        structure: buffer.toString(),
      );
    } catch (_) {
      projectContext = null;
    }
  }

  Future<void> _injectContext() async {
    if (projectContext == null) return;

    final ctx = StringBuffer();
    ctx.writeln("\n## Current Project Context");
    ctx.writeln(projectContext!.structure);

    if (projectContext!.configFiles.containsKey("package.json")) {
      ctx.writeln("\n### package.json");
      ctx.writeln("```json");
      ctx.writeln(projectContext!.configFiles["package.json"]);
      ctx.writeln("```");
    }

    if (projectContext!.configFiles.containsKey("README.md")) {
      final readme = projectContext!.configFiles["README.md"]!;
      if (readme.length < 1500) {
        ctx.writeln("\n### README.md");
        ctx.writeln(readme);
      }
    }

    messages.insert(
        1, Message(role: "system", content: ctx.toString()));

    // Inject user profile
    final profileCtx = await UserProfile.toContextPrompt();
    messages.insert(
        1, Message(role: "system", content: profileCtx));
  }

  /// Load saved session from disk
  Future<bool> loadSession() async {
    final saved = await SessionMemory.loadChat(projectName);
    if (saved == null || saved.isEmpty) return false;

    messages.clear();
    messages.add(Message(
        role: "system",
        content: _buildSystemPrompt(currentMode)));
    messages.addAll(saved);
    await _injectContext();

    final decisions =
        await SessionMemory.getDecisions(projectName);
    if (decisions.isNotEmpty) {
      final mem = StringBuffer();
      mem.writeln("\n## Project Memory (previous decisions)");
      for (final d in decisions.reversed.take(5)) {
        mem.writeln("- ${d["topic"]}: ${d["decision"]}");
      }
      messages.insert(
          1, Message(role: "system", content: mem.toString()));
    }

    return true;
  }

  /// Save current session to disk
  Future<void> saveSession() async {
    final nonSystem =
        messages.where((m) => m.role != "system").toList();
    if (nonSystem.length > 2) {
      await SessionMemory.saveChat(projectName, nonSystem);
    }
  }

  /// Remember an important decision
  Future<void> remember(String topic, String decision) async {
    await SessionMemory.rememberDecision(
        projectName, topic, decision);
  }

  /// Compress context if conversation is too long
  void maybeCompress() {
    if (messages.length > 30) {
      messages.setAll(
          0, ContextManager.compress(messages, keepLast: 6));
    }
  }

  static String _buildSystemPrompt(AgentMode mode) {
    final modeInstructions = switch (mode) {
      AgentMode.brainstorm => """
## MODE: BRAINSTORM
You are in creative ideation mode. No tools. Just ideas.
- Propose 3-5 solutions with pros/cons for each.
- Ask clarifying questions before committing to a direction.
- Think about trade-offs: simplicity vs power, speed vs maintainability.
- Suggest unconventional approaches. Challenge assumptions.
- Output structured: Problem → Options → Recommendation.
""",
      AgentMode.architect => """
## MODE: ARCHITECT
You are in architecture planning mode. Read code first, then plan.
- Map component dependencies before proposing changes.
- Consider: data flow, error paths, scaling, testability.
- Propose file-by-file implementation plan with rationale.
- Flag risks: breaking changes, tight coupling, missing error handling.
- Output: Component Diagram (ASCII) → Data Flow → Files to Touch → Risks.
""",
      AgentMode.code => """
## MODE: CODE WRITER
You are in implementation mode. Write production-quality code.
- Read existing files first. Match the project's exact style.
- Write minimal working version. Handle edge cases.
- After writing: verify logic. Suggest tests.
- For multi-file changes: list all files and their role.
- Use git_sync after each complete logical change. Meaningful commits.
""",
      AgentMode.debug => """
## MODE: DEBUGGER
You are in debugging mode. Find root cause, don't guess.
- Reproduce: what exact input triggers it?
- Trace: follow the error from symptom to source.
- Hypothesize: "If X caused this, we'd also see Y. Do we?"
- Fix minimal. Test. Verify.
- Check: similar bugs in nearby code?
""",
      AgentMode.refactor => """
## MODE: REFACTOR
You are in refactoring mode. Change structure, preserve behavior.
- One change at a time. Verify each step.
- Extract functions >50 lines. Inline single-use variables.
- Simplify conditionals. Replace switch with strategy.
- Ensure tests pass. Match existing conventions.
- Never: add features while refactoring. Never refactor without reading code first.
""",
      AgentMode.research => """
## MODE: DEEP RESEARCH
You are in research mode. Investigate topics thoroughly.
- Search the web for current information using web_search tool.
- Fetch and read documentation with web_fetch tool.
- Compare multiple sources. Note disagreements.
- Synthesize findings into structured report.
- Cite sources. Distinguish facts from opinions.
- Output: Executive Summary → Key Findings → Detailed Analysis → Recommendations → Sources.
""",
      AgentMode.auto => """
## MODE: AUTO
Detect what the user needs and switch modes automatically.
- "research...", "what is...", "compare...", "latest...", "best practices for..." → research
- "how to...", "what if...", "design...", "ideas for..." → brainstorm
- "plan...", "architecture...", "structure..." → architect
- "write...", "add...", "create...", "implement..." → code
- "fix...", "bug...", "broken...", "error..." → debug
- "refactor...", "clean up...", "improve...", "restructure..." → refactor
""",
    };

    return """
You are OpenCode Mobile — a professional AI coding agent.
You work on Android, managing real projects synced via GitHub.
You are NOT a chatbot. You are a software engineer. Act like one.

$modeInstructions

## Knowledge Base (always available)
${SkillKnowledge.all}

## Tools
- read_file(project, path) — read any file
- write_file(project, path, content) — create/overwrite a file  
- list_files(project, path?) — browse directory
- delete_file(project, path) — delete a file
- search_code(project, pattern, fileExt?) — search text in files
- git_sync(project, message) — commit and push to GitHub
- git_status(project) — check changed files

## Workflow
1. Understand the task. Ask clarifying questions if needed.
2. Read relevant files. search_code to find patterns.
3. Plan small. Implement small. Verify. Commit.
4. After writing code: double-check logic. Handle edge cases.
5. Use meaningful git commit messages: type(scope): what changed.
6. Be concise. Code over words. Action over explanation.

## Universal Code Rules
- No try/catch unless unavoidable. No 'any' in TypeScript.
- Early returns. const > let. Ternaries > reassignment.
- Functions < 50 lines. Files < 300 lines.
- Handle null/empty/wrong-type. Error messages say what+why+fix.
- Match existing project style EXACTLY. Read before write.
- Never: secrets in code, empty catch, eval with user input.
""";
  }

  static final List<Map<String, dynamic>> _tools = [
    {
      "type": "function",
      "function": {
        "name": "read_file",
        "description": "Read contents of a file",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "path": {"type": "string"},
          },
          "required": ["project", "path"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "write_file",
        "description":
            "Write content to a file. Creates directories if needed.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "path": {"type": "string"},
            "content": {"type": "string"},
          },
          "required": ["project", "path", "content"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "list_files",
        "description": "List files in a directory",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "path": {"type": "string"},
          },
          "required": ["project"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "delete_file",
        "description": "Delete a file",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "path": {"type": "string"},
          },
          "required": ["project", "path"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "search_code",
        "description":
            "Search for text patterns in project files. Use to find functions, types, imports, patterns.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "pattern": {"type": "string"},
            "fileExt": {"type": "string"},
          },
          "required": ["project", "pattern"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "git_sync",
        "description":
            "Commit all changes and push to GitHub. Use meaningful commit messages: type(scope): description.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "message": {"type": "string"},
          },
          "required": ["project", "message"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "git_status",
        "description": "Check git working tree status",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
          },
          "required": ["project"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "web_search",
        "description":
            "Search the web for current information. Use for research, documentation lookups, comparing technologies, finding solutions. Returns titles, snippets, and URLs.",
        "parameters": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "Search query",
            },
            "max_results": {
              "type": "integer",
              "description": "Max results (1-10, default 5)",
            },
          },
          "required": ["query"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "web_fetch",
        "description":
            "Fetch and read content from a URL. Use to read documentation, articles, or any web page. Returns extracted text.",
        "parameters": {
          "type": "object",
          "properties": {
            "url": {
              "type": "string",
              "description": "Full URL to fetch",
            },
          },
          "required": ["url"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "impact_analysis",
        "description":
            "Analyze what files would be affected if a given file is changed. Shows direct and transitive dependents with risk level.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {
              "type": "string",
              "description": "File path to analyze",
            },
          },
          "required": ["project", "file_path"],
        },
      },
    },
  ];

  void setMode(AgentMode mode) {
    currentMode = mode;
    reset();
  }

  AgentMode _detectMode(String userMessage) {
    final lower = userMessage.toLowerCase();

    if (lower.contains("research") ||
        lower.contains("what is") ||
        lower.contains("compare") ||
        lower.contains("latest") ||
        lower.contains("best practice") ||
        lower.contains("explain ") &&
            !lower.contains("code")) {
      return AgentMode.research;
    }
    if (lower.contains("how ") &&
        (lower.contains("design") ||
            lower.contains("architecture") ||
            lower.contains("structure") ||
            lower.contains("plan"))) {
      return AgentMode.architect;
    }
    if (lower.contains(" how ") ||
        lower.contains("what if") ||
        lower.contains("brainstorm") ||
        lower.contains("ideas") ||
        lower.contains("suggest") ||
        lower.contains("options")) {
      if (!lower.contains("write") &&
          !lower.contains("add") &&
          !lower.contains("create") &&
          !lower.contains("implement")) {
        return AgentMode.brainstorm;
      }
    }
    if (lower.contains("fix") ||
        lower.contains("bug") ||
        lower.contains("broken") ||
        lower.contains("error") ||
        lower.contains("wrong") ||
        lower.contains("debug") ||
        lower.contains("trace")) {
      return AgentMode.debug;
    }
    if (lower.contains("refactor") ||
        lower.contains("clean") ||
        lower.contains("restructure") ||
        lower.contains("extract") ||
        lower.contains("simplify")) {
      return AgentMode.refactor;
    }
    return AgentMode.code;
  }

  Future<String> _executeTool(
      String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case "read_file":
          return await StorageService.readFile(
              args["project"], args["path"]);
        case "write_file":
          await StorageService.writeFile(
              args["project"], args["path"], args["content"]);
          return "File written: ${args["path"]}";
        case "list_files":
          final entries = await StorageService.listDir(
              args["project"], args["path"] ?? "");
          if (entries.isEmpty) return "(empty)";
          return entries
              .map((e) {
                final name = e.uri.pathSegments.last;
                final isDir = e is Directory;
                return isDir ? "[DIR]  $name/" : "       $name";
              })
              .join("\n");
        case "delete_file":
          await StorageService.deleteFile(
              args["project"], args["path"]);
          return "Deleted: ${args["path"]}";
        case "search_code":
          final results = await StorageService.searchCode(
            args["project"],
            args["pattern"],
            args["fileExt"],
          );
          return results.isEmpty
              ? "No matches"
              : results.join("\n");
        case "git_sync":
          final gs = gitService;
          if (gs == null) return "Git not configured";
          return await gs.commitAndPush(args["message"]);
        case "git_status":
          final gs = gitService;
          if (gs == null) return "Git not configured";
          return await gs.getStatus();
        case "web_search":
          final results = await ResearchService.search(
              args["query"],
              maxResults: args["max_results"] ?? 5);
          if (results.isEmpty) return "No results found";
          return results
              .map((r) =>
                  "${r.title}\n  ${r.snippet}\n  ${r.url}")
              .join("\n\n");
        case "web_fetch":
          return await ResearchService.fetchUrl(args["url"]);
        case "impact_analysis":
          final impact = await CodeIntelligence.analyzeImpact(
              args["project"], args["file_path"]);
          return "Risk: ${impact.riskLevel}\n"
              "Direct dependents (${impact.directDependents.length}):\n"
              "${impact.directDependents.map((d) => "  - $d").join("\n")}\n"
              "Transitive dependents (${impact.transitiveDependents.length}):\n"
              "${impact.transitiveDependents.map((d) => "  - $d").join("\n")}";
        default:
          return "Unknown tool: $name";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  Stream<String> sendMessage(String userMessage) async* {
    if (currentMode == AgentMode.auto) {
      final detected = _detectMode(userMessage);
      if (detected != AgentMode.code) {
        currentMode = detected;
        yield "[MODE: ${detected.name.toUpperCase()}]\n";
      }
    }

    messages.add(Message(role: "user", content: userMessage));
    maybeCompress();

    int loopCount = 0;
    const maxLoops = 20;

    while (loopCount < maxLoops) {
      loopCount++;

      final body = jsonEncode({
        "model": "deepseek-chat",
        "messages": messages.map((m) => m.toJson()).toList(),
        "tools": _tools,
        "temperature": currentMode == AgentMode.brainstorm ? 0.7 : 0.2,
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
      );

      if (response.statusCode != 200) {
        yield "API Error (${response.statusCode}): ${response.body}";
        return;
      }

      final json = jsonDecode(response.body);
      final choice = json["choices"][0];
      final msg = choice["message"];

      if (msg["content"] != null &&
          (msg["content"] as String).isNotEmpty) {
        yield msg["content"];
      }

      if (msg["tool_calls"] != null &&
          (msg["tool_calls"] as List).isNotEmpty) {
        final toolCalls =
            (msg["tool_calls"] as List).map((tc) {
          return ToolCall(
            id: tc["id"],
            name: tc["function"]["name"],
            arguments: tc["function"]["arguments"],
          );
        }).toList();

        messages.add(Message(
          role: "assistant",
          content: msg["content"] ?? "",
          toolCalls: toolCalls,
        ));

        for (final tc in msg["tool_calls"]) {
          final fn = tc["function"];
          final toolName = fn["name"] as String;

          Map<String, dynamic> toolArgs;
          try {
            toolArgs = Map<String, dynamic>.from(
                jsonDecode(fn["arguments"]));
          } catch (_) {
            toolArgs = {};
          }

          final argsStr = fn["arguments"].toString();
          final preview = argsStr.length > 60
              ? "${argsStr.substring(0, 60)}..."
              : argsStr;
          yield "\n[🔧 $toolName] $preview\n";

          final result =
              await _executeTool(toolName, toolArgs);
          yield result;

          messages.add(Message(
            role: "tool",
            content: result,
            toolCallId: tc["id"],
          ));
        }
        continue;
      }

      messages.add(Message(
          role: "assistant", content: msg["content"] ?? ""));
      break;
    }

    saveSession();
  }

  Future<void> reset() async {
    messages.clear();
    messages.add(Message(
        role: "system",
        content: _buildSystemPrompt(currentMode)));
    if (projectContext != null) {
      await _injectContext();
    }
  }
}
