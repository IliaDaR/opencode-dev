import "dart:convert";
import "dart:io";
import "package:http/http.dart" as http;
import "storage_service.dart";
import "git_service.dart";
import "github_service.dart";
import "browser_service.dart";
import "sql_service.dart";
import "lsp_service.dart";
import "sub_agent_service.dart";
import "deployment_service.dart";
import "project_service.dart";
import "code_generation_service.dart";
import "brainstorm_engine.dart";
import "snapshot_service.dart";
import "compaction_service.dart";
import "multi_provider_service.dart";
import "permission_service.dart";
import "formatter_service.dart";
import "mcp_client.dart";
import "diff_service.dart";
import "error_recovery_service.dart";
import "code_index.dart";
import "execution_plan_service.dart";
import "self_review_service.dart";
import "autonomous_loop.dart";
import "project_onboarding.dart";
import "error_learning_service.dart";
import "security_scan_service.dart";
import "api_tester.dart";
import "debate_service.dart";
import "code_sandbox.dart";
import "dependency_updater.dart";
import "interactive_debugger.dart";
import "merge_conflict_resolver.dart";
import "performance_profiler.dart";
import "daily_standup_service.dart";
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

  void Function(String tool, String args)? onToolCall;
  void Function(String tool, String args, String result)? onToolResult;

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

    // Inject learned error patterns
    try {
      final errors =
          await ErrorLearningService.getContext(projectName);
      if (errors.isNotEmpty) {
        messages.insert(
            1, Message(role: "system", content: errors));
      }
    } catch (_) {}
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
## MODE: CREATIVE IDEATION
${BrainstormEngine.prompt}
""",
      AgentMode.architect => """
## MODE: ARCHITECT
Plan systems at hyper-scale. Think about failure modes before happy path.
- Map every dependency. Find hidden couplings.
- Design for 10x growth, implement for 1x.
- Consider: CAP, latency budgets, fault tolerance, graceful degradation.
- Output: System Diagram → Data Flow → Failure Modes → Implementation Plan → Migration Path.
""",
      AgentMode.code => """
## MODE: HYPER-ENGINEER
${AutonomousLoop.systemPrompt}
""",
      AgentMode.debug => """
## MODE: DEBUGGER
Trace bugs with surgical precision. Find the ONE root cause.
- Reproduce: exact input, exact state, exact environment.
- Isolate: binary search through code and git history.
- Prove: "If X is the cause, we'd also see Y. Do we?" Eliminate false hypotheses.
- Fix MINIMALLY. One line if possible. Then verify fix doesn't break anything.
- Prevent: find similar patterns elsewhere that have the same bug.
""",
      AgentMode.refactor => """
## MODE: REFACTOR
Restructure for clarity without changing ANY behavior. Tests must pass before and after.
- One change → verify → commit → next change. Never batch refactorings.
- Extract: functions >50 lines, duplicated logic, magic values.
- Simplify: deep nesting, complex conditionals, god objects.
- NEVER: add features, change APIs, modify test expectations.
""",
      AgentMode.research => """
## MODE: DEEP RESEARCH
Investigate thoroughly. Search the web. Read docs. Compare implementations on GitHub.
- Phase 1: Gather. web_search for current info. github_search_code for real examples.
- Phase 2: Analyze. Compare approaches. Note trade-offs. Find consensus and disagreement.
- Phase 3: Synthesize. Executive summary. Key findings with confidence levels. Recommendations.
- Always cite sources. Distinguish fact from opinion. Note when info may be outdated.
""",
      AgentMode.auto => """
## MODE: AUTO
Detect the user's INTENT, not just keywords. Then choose the optimal approach.

Quick decisions: do it yourself.
Complex decisions: delegate to sub-agent (delegate_task tool).
Novel ideas needed: use BrainstormEngine techniques.
Code needed: write yourself or delegate to scribe sub-agent.
Multiple independent tasks: delegate in PARALLEL to save time.

Detection:
- "research", "what is", "compare", "latest" → research mode + web_search
- "how to design", "architecture", "plan" → architect mode
- "write code", "add", "implement" → code mode + delegate to scribe
- "fix bug", "broken", "error" → debug mode + delegate to debugger
- "refactor", "clean up" → refactor mode
- "ideas", "brainstorm", "invent" → brainstorm mode
""",
    };

    return """
## IDENTITY

You are OPENCODE — a hyper-engineer AI agent. You operate at a level beyond senior engineers.
You don't just write code. You architect systems, invent solutions, and orchestrate sub-agents.
You understand the user deeply — their goals, their style, their unspoken constraints.

## CORE PRINCIPLES

1. UNDERSTAND BEFORE ACTING
   - Read the project context. Read existing code. Read the user's profile.
   - Ask clarifying questions when the intent is ambiguous.
   - Never assume. Never guess. Verify with tools.

2. ORCHESTRATE, DON'T MICROMANAGE
   - For complex tasks, delegate to specialized sub-agents via delegate_task.
   - Run independent sub-tasks in PARALLEL.
   - You are the conductor. Sub-agents are your orchestra.
   - Agent types: architect (plan), scribe (code), debugger (fix), reviewer (check), refactor (restructure), researcher (investigate).

3. WRITE FLAWLESS CODE
   - Every function handles null, empty, error, and edge cases.
   - Every file follows the project's existing conventions EXACTLY.
   - After writing, diagnose yourself. find_patterns to check consistency.
   - Use edit_file for changes, not write_file (preserve rest of file).

4. THINK CREATIVELY
   - When asked for ideas, use lateral thinking: inversion, analogy, combination, constraint removal.
   - Never suggest obvious solutions. Challenge assumptions.
   - Generate ideas that don't exist yet. Combine unrelated domains.

5. VERIFY EVERYTHING
   - After code changes: diagnose_file, check_imports, run tests.
   - After architecture plans: impact_analysis to see what breaks.
   - After research: cite sources. Cross-reference.

6. COMMIT WITH MEANING
   - type(scope): description — feat, fix, docs, chore, refactor, test.
   - One commit per logical change. Never batch unrelated work.
   - Describe WHY, not WHAT.

$modeInstructions

## KNOWLEDGE BASE
${SkillKnowledge.all}

## AVAILABLE TOOLS
You have 43 tools available. Key categories:

FILE: read_file, write_file, edit_file, delete_file, list_files, glob_files, search_code
GIT: git_sync, git_status
GITHUB API: github_list_issues, github_create_issue, github_list_prs, github_get_pr, github_search_code, github_get_file, github_get_repo
WEB: web_search, web_fetch, browser_open, browser_extract, browser_follow
TERMINAL: run_command
SQL: sql_detect, sql_query, sql_schema
QUALITY: diagnose_file, analyze_project, check_imports, find_patterns, suggest_tests
INTELLIGENCE: impact_analysis, ask_user, create_tasks
DEPLOY: check_deploy_readiness, generate_docker_compose, generate_ci_config
DELEGATE: delegate_task (architect | scribe | debugger | reviewer | refactor | researcher)

## CODE RULES
- No try/catch unless unavoidable. No 'any' in TypeScript. No 'else'.
- Early returns. const > let. Ternaries > reassignment.
- Functions < 50 lines. Files < 300 lines.
- Handle null/empty/wrong-type. Error messages: what+why+fix.
- Match existing project style EXACTLY. Read before write.
- Never: secrets in code, empty catch, eval with user input, == in JS.
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
    {
      "type": "function",
      "function": {
        "name": "run_command",
        "description":
            "Execute a terminal command and return the output. Use for: running tests, typecheck, lint, build, npm/pip install, git commands beyond sync/status, or any shell operation.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "command": {
              "type": "string",
              "description": "Shell command to run",
            },
            "cwd": {
              "type": "string",
              "description":
                  "Working directory relative to project root (optional)",
            },
          },
          "required": ["project", "command"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "glob_files",
        "description":
            "Find files matching a glob pattern. Use to discover project structure. Example patterns: '**/*.ts', 'src/**/*.tsx', '*.json'.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "pattern": {
              "type": "string",
              "description": "Glob pattern",
            },
          },
          "required": ["project", "pattern"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "edit_file",
        "description":
            "Edit specific lines in an existing file. Use instead of write_file when modifying existing code — preserves the rest of the file. Provide old_string (text to replace) and new_string (replacement).",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "path": {"type": "string"},
            "old_string": {
              "type": "string",
              "description":
                  "Exact text to find and replace",
            },
            "new_string": {
              "type": "string",
              "description": "Replacement text",
            },
          },
          "required": [
            "project",
            "path",
            "old_string",
            "new_string"
          ],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "create_tasks",
        "description":
            "Create a structured task list to track progress. Use for complex multi-step work. Provide list of tasks with statuses.",
        "parameters": {
          "type": "object",
          "properties": {
            "tasks": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "content": {
                    "type": "string",
                    "description":
                        "Task description",
                  },
                  "status": {
                    "type": "string",
                    "enum": [
                      "pending",
                      "in_progress",
                      "completed",
                      "cancelled"
                    ],
                  },
                  "priority": {
                    "type": "string",
                    "enum": [
                      "high",
                      "medium",
                      "low"
                    ],
                  },
                },
                "required": [
                  "content",
                  "status",
                  "priority"
                ],
              },
              "description": "List of tasks",
            },
          },
          "required": ["tasks"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "ask_user",
        "description":
            "Ask the user a clarifying question when you need more information. Use when requirements are ambiguous or you need to choose between approaches.",
        "parameters": {
          "type": "object",
          "properties": {
            "question": {"type": "string"},
            "options": {
              "type": "array",
              "items": {"type": "string"},
            },
          },
          "required": ["question"],
        },
      },
    },
    // GitHub API tools
    {
      "type": "function",
      "function": {
        "name": "github_list_issues",
        "description":
            "List GitHub issues for a repository. Use to find bugs, feature requests, or tasks.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {
              "type": "string",
              "description": "Repo owner",
            },
            "repo": {
              "type": "string",
              "description": "Repo name",
            },
            "state": {
              "type": "string",
              "description":
                  "Issue state: open, closed, all",
            },
            "label": {"type": "string"},
          },
          "required": ["owner", "repo"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "github_create_issue",
        "description":
            "Create a new GitHub issue.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {"type": "string"},
            "repo": {"type": "string"},
            "title": {"type": "string"},
            "body": {"type": "string"},
            "labels": {
              "type": "array",
              "items": {"type": "string"},
            },
          },
          "required": [
            "owner",
            "repo",
            "title",
            "body"
          ],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "github_list_prs",
        "description":
            "List pull requests for a repository.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {"type": "string"},
            "repo": {"type": "string"},
            "state": {
              "type": "string",
              "description":
                  "PR state: open, closed, all",
            },
          },
          "required": ["owner", "repo"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "github_get_pr",
        "description":
            "Get details of a specific pull request including changed files.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {"type": "string"},
            "repo": {"type": "string"},
            "number": {"type": "integer"},
          },
          "required": [
            "owner",
            "repo",
            "number"
          ],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "github_search_code",
        "description":
            "Search code across GitHub. Use to find examples, implementations, or usage patterns.",
        "parameters": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description":
                  "Search query (supports GitHub search syntax)",
            },
          },
          "required": ["query"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "github_get_file",
        "description":
            "Read a file directly from a GitHub repository without cloning.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {"type": "string"},
            "repo": {"type": "string"},
            "path": {
              "type": "string",
              "description": "File path in repo",
            },
            "ref": {
              "type": "string",
              "description":
                  "Branch/tag (default: main)",
            },
          },
          "required": [
            "owner",
            "repo",
            "path"
          ],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "github_get_repo",
        "description":
            "Get repository info: stars, language, description, open issues.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {"type": "string"},
            "repo": {"type": "string"},
          },
          "required": ["owner", "repo"],
        },
      },
    },
    // Browser/web tools
    {
      "type": "function",
      "function": {
        "name": "browser_open",
        "description":
            "Open a web page and extract its content — title, headings, links, text. Like reading a webpage in a browser.",
        "parameters": {
          "type": "object",
          "properties": {
            "url": {
              "type": "string",
              "description": "Full URL to open",
            },
          },
          "required": ["url"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "browser_extract",
        "description":
            "Extract specific data from a web page using a regex pattern. Useful for scraping structured data.",
        "parameters": {
          "type": "object",
          "properties": {
            "url": {"type": "string"},
            "pattern": {
              "type": "string",
              "description":
                  "Regex pattern with capture groups",
            },
          },
          "required": ["url", "pattern"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "browser_follow",
        "description":
            "Click/follow a link on a web page by its text.",
        "parameters": {
          "type": "object",
          "properties": {
            "url": {
              "type": "string",
              "description": "Current page URL",
            },
            "link_text": {
              "type": "string",
              "description": "Text of the link to click",
            },
          },
          "required": ["url", "link_text"],
        },
      },
    },
    // SQL tools
    {
      "type": "function",
      "function": {
        "name": "sql_detect",
        "description":
            "Detect SQLite databases in the project.",
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
        "name": "sql_query",
        "description":
            "Run an SQL query against a SQLite database in the project.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "db_file": {
              "type": "string",
              "description": "Database filename",
            },
            "query": {
              "type": "string",
              "description": "SQL query to run",
            },
          },
          "required": [
            "project",
            "db_file",
            "query"
          ],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "sql_schema",
        "description":
            "Show the schema of a SQLite database — all tables and their columns.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "db_file": {"type": "string"},
          },
          "required": ["project", "db_file"],
        },
      },
    },
    // Code quality tools
    {
      "type": "function",
      "function": {
        "name": "find_patterns",
        "description":
            "Find similar code patterns across the project. Useful for discovering conventions, duplicated code, or finding all usages of an API.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "pattern": {
              "type": "string",
              "description":
                  "Code pattern to search for",
            },
          },
          "required": ["project", "pattern"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "suggest_tests",
        "description":
            "Analyze a source file and suggest what tests should be written.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
          },
          "required": ["project", "file_path"],
        },
      },
    },
    // LSP / Diagnostics tools
    {
      "type": "function",
      "function": {
        "name": "diagnose_file",
        "description":
            "Analyze a file for code quality issues: any types, missing imports, security risks, anti-patterns, TODO comments. Returns diagnostics with line numbers.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
          },
          "required": ["project", "file_path"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "analyze_project",
        "description":
            "Scan the entire project for code quality issues across all source files. Returns summary with top issues per file.",
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
        "name": "check_imports",
        "description":
            "Verify that all relative imports in a file reference real files. Finds broken imports.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
          },
          "required": ["project", "file_path"],
        },
      },
    },
    // Multi-agent delegation
    {
      "type": "function",
      "function": {
        "name": "delegate_task",
        "description":
            "Delegate a task to a specialized sub-agent (architect, scribe, debugger, reviewer, refactor, researcher).",
        "parameters": {
          "type": "object",
          "properties": {
            "agent_type": {
              "type": "string",
              "enum": [
                "architect",
                "scribe",
                "debugger",
                "reviewer",
                "refactor",
                "researcher",
              ],
            },
            "task": {"type": "string"},
          },
          "required": ["agent_type", "task"],
        },
      },
    },
    // Deployment tools
    {
      "type": "function",
      "function": {
        "name": "check_deploy_readiness",
        "description":
            "Check if a project is ready for deployment: Dockerfile, .gitignore, lockfile, README, CI config, env template.",
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
        "name": "generate_docker_compose",
        "description":
            "Generate docker-compose.yml for common stacks: node-postgres, python-postgres, node-mongo.",
        "parameters": {
          "type": "object",
          "properties": {
            "stack": {
              "type": "string",
              "description": "Stack type",
            },
            "config": {
              "type": "object",
              "description":
                  "Config: port, db name, etc.",
            },
          },
          "required": ["stack"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "generate_ci_config",
        "description":
            "Generate CI/CD pipeline config for GitHub Actions.",
        "parameters": {
          "type": "object",
          "properties": {
            "platform": {
              "type": "string",
              "description":
                  "github-node, github-python, github-flutter",
            },
            "node_version": {"type": "string"},
            "python_version": {"type": "string"},
          },
          "required": ["platform"],
        },
      },
    },
    // Code generation tools
    {
      "type": "function",
      "function": {
        "name": "generate_test_template",
        "description":
            "Generate a test file template for a source file — auto-discovers functions and creates test stubs.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "source_file": {"type": "string"},
          },
          "required": ["project", "source_file"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "generate_boilerplate",
        "description":
            "Generate project boilerplate: express-api, react-component, python-fastapi, flutter-screen.",
        "parameters": {
          "type": "object",
          "properties": {
            "project_type": {"type": "string"},
            "name": {
              "type": "string",
              "description": "Component/Project name",
            },
          },
          "required": ["project_type", "name"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "suggest_optimizations",
        "description":
            "Analyze code and suggest performance optimizations: N+1 queries, inefficient loops, missing memo, sync in async.",
        "parameters": {
          "type": "object",
          "properties": {
            "code": {
              "type": "string",
              "description": "Code snippet to analyze",
            },
          },
          "required": ["code"],
        },
      },
    },
    // Project management tools
    {
      "type": "function",
      "function": {
        "name": "estimate_effort",
        "description":
            "Estimate development effort for a task based on description. Covers: features, bug fixes, refactoring, API, DB, UI, testing, docs, auth, DevOps.",
        "parameters": {
          "type": "object",
          "properties": {
            "description": {
              "type": "string",
              "description": "Task description",
            },
          },
          "required": ["description"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "generate_readme",
        "description":
            "Generate a README.md template for a project.",
        "parameters": {
          "type": "object",
          "properties": {
            "project_name": {"type": "string"},
            "description": {"type": "string"},
            "tech_stack": {"type": "string"},
          },
          "required": [
            "project_name",
            "description",
            "tech_stack"
          ],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "generate_api_docs",
        "description":
            "Generate API documentation from a source file — extracts exported functions, parameters, return types, JSDoc.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "source_file": {"type": "string"},
          },
          "required": ["project", "source_file"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "snapshot_undo",
        "description": "Undo the last change to a file. Restores previous version from snapshot.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
          },
          "required": ["project", "file_path"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "snapshot_undo_all",
        "description": "Undo ALL changes in this session. Restores all modified files.",
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
        "name": "format_code",
        "description": "Format source code using appropriate formatter (prettier/ruff/dart fmt/gofmt).",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
          },
          "required": ["project", "file_path"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "batch_execute",
        "description": "Execute multiple independent tool calls in parallel.",
        "parameters": {
          "type": "object",
          "properties": {
            "calls": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "tool": {"type": "string"},
                  "args": {"type": "object"},
                },
                "required": ["tool", "args"],
              },
            },
          },
          "required": ["calls"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "mcp_call",
        "description": "Call a tool on a remote MCP (Model Context Protocol) server via HTTP. Provide server URL, tool name, arguments.",
        "parameters": {
          "type": "object",
          "properties": {
            "url": {"type": "string"},
            "tool": {"type": "string"},
            "args": {"type": "object"},
          },
          "required": ["url", "tool", "args"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "diff_preview",
        "description": "Preview the diff of a pending edit before applying it. Shows what lines will be added and removed.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
            "old_string": {"type": "string"},
            "new_string": {"type": "string"},
          },
          "required": ["project", "file_path", "old_string", "new_string"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "create_plan",
        "description": "Create a structured execution plan for complex tasks.",
        "parameters": {
          "type": "object",
          "properties": {
            "task": {"type": "string"},
          },
          "required": ["task"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "self_review",
        "description": "Review your own code changes before committing. Checks for bugs, style issues, and anti-patterns. Use before git_sync.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string", "description": "Specific file to review (optional, omit for all changed files)"},
          },
          "required": ["project"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "project_summary",
        "description": "Get a comprehensive summary of a project: tech stack, dependencies, structure. Use when opening a project.",
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
        "name": "security_scan",
        "description": "Scan the entire project for OWASP Top 10 vulnerabilities: hardcoded secrets, injection risks, weak crypto, auth issues.",
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
        "name": "api_test",
        "description": "Test a REST API endpoint. GET or POST. Returns status code and response body.",
        "parameters": {
          "type": "object",
          "properties": {
            "method": {"type": "string", "enum": ["GET", "POST"]},
            "url": {"type": "string"},
            "body": {"type": "string", "description": "Request body for POST"},
            "headers": {"type": "object", "description": "Custom headers"},
          },
          "required": ["method", "url"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "debate",
        "description": "Run a structured debate between two sub-agents on a topic. Agent1 argues FOR, Agent2 argues AGAINST. Synthesize the resolution.",
        "parameters": {
          "type": "object",
          "properties": {
            "topic": {"type": "string"},
            "agent1": {"type": "string", "description": "First sub-agent type"},
            "agent2": {"type": "string", "description": "Second sub-agent type"},
          },
          "required": ["topic", "agent1", "agent2"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "create_pr",
        "description": "Create a GitHub Pull Request with the current changes. Use after committing.",
        "parameters": {
          "type": "object",
          "properties": {
            "owner": {"type": "string"},
            "repo": {"type": "string"},
            "title": {"type": "string"},
            "body": {"type": "string"},
            "head": {"type": "string", "description": "Source branch (default: master)"},
            "base": {"type": "string", "description": "Target branch (default: main)"},
          },
          "required": ["owner", "repo", "title", "body"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "run_code",
        "description": "Run code in a sandbox. Supports js/py/dart/sh. Auto-detects language.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "code": {"type": "string"},
            "language": {"type": "string"},
          },
          "required": ["project", "code"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "check_deps",
        "description": "Check for outdated npm/pip dependencies.",
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
        "name": "analyze_function",
        "description": "Analyze a function: variables, returns, bugs, complexity.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
            "function_name": {"type": "string"},
          },
          "required": ["project","file_path","function_name"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "detect_conflicts",
        "description": "Detect merge conflicts and show resolution strategy.",
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
        "name": "profile_performance",
        "description": "Analyze code for performance bottlenecks.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
            "file_path": {"type": "string"},
          },
          "required": ["project"],
        },
      },
    },
    {
      "type": "function",
      "function": {
        "name": "daily_standup",
        "description": "Generate a daily standup summary from git history: what was done today.",
        "parameters": {
          "type": "object",
          "properties": {
            "project": {"type": "string"},
          },
          "required": ["project"],
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
          await SnapshotService.init();
          await SnapshotService.snapshot(
              args["project"], args["path"]);
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
          await SnapshotService.snapshot(
              args["project"], args["path"]);
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
        case "run_command":
          return await _runShellCommand(
              args["project"],
              args["command"],
              args["cwd"]);
        case "glob_files":
          return await _globSearch(
              args["project"], args["pattern"]);
        case "edit_file":
          return await _editFile(
              args["project"],
              args["path"],
              args["old_string"],
              args["new_string"]);
        case "create_tasks":
          final tasks = args["tasks"] as List;
          final buf = StringBuffer();
          buf.writeln("## Task List\n");
          for (final t in tasks) {
            final icon = switch (t["status"]) {
              "completed" => "✅",
              "in_progress" => "🔄",
              "cancelled" => "❌",
              _ => "⏳",
            };
            buf.writeln(
                "$icon [${t["priority"]}] ${t["content"]}");
            buf.writeln();
          }
          return buf.toString();
        case "ask_user":
          final q = args["question"] as String;
          final opts = args["options"] as List?;
          if (opts != null && opts.isNotEmpty) {
            return "❓ $q\n\nOptions: ${opts.join(", ")}";
          }
          return "❓ $q";
        // GitHub tools
        case "github_list_issues":
          return await GitHubService.listIssues(
              args["owner"], args["repo"],
              state: args["state"] ?? "open",
              label: args["label"]);
        case "github_create_issue":
          return await GitHubService.createIssue(
              args["owner"], args["repo"],
              args["title"], args["body"],
              labels: args["labels"]?.cast<String>());
        case "github_list_prs":
          return await GitHubService.listPRs(
              args["owner"], args["repo"],
              state: args["state"] ?? "open");
        case "github_get_pr":
          return await GitHubService.getPR(
              args["owner"], args["repo"], args["number"]);
        case "github_search_code":
          return await GitHubService.searchCode(
              args["query"]);
        case "github_get_file":
          return await GitHubService.getFileContent(
              args["owner"], args["repo"], args["path"],
              ref: args["ref"] ?? "main");
        case "github_get_repo":
          return await GitHubService.getRepo(
              args["owner"], args["repo"]);
        // Browser tools
        case "browser_open":
          return await BrowserService.openPage(args["url"]);
        case "browser_extract":
          return await BrowserService.extractData(
              args["url"], args["pattern"]);
        case "browser_follow":
          return await BrowserService.followLink(
              args["url"], args["link_text"]);
        // SQL tools
        case "sql_detect":
          return await SqlService.detectDatabases(
              args["project"]);
        case "sql_query":
          return await SqlService.runQuery(args["project"],
              args["db_file"], args["query"]);
        case "sql_schema":
          return await SqlService.showSchema(
              args["project"], args["db_file"]);
        // Code quality
        case "find_patterns":
          final matches =
              await CodeIntelligence.findSimilarPatterns(
                  args["project"], args["pattern"]);
          if (matches.isEmpty) return "No matches found";
          return matches
              .map((m) => "${m.file}:${m.line}\n  ${m.snippet}")
              .join("\n\n");
        case "suggest_tests":
          return await _suggestTests(
              args["project"], args["file_path"]);
        // LSP tools
        case "diagnose_file":
          return await LspService.diagnoseFile(
              args["project"], args["file_path"]);
        case "analyze_project":
          return await LspService.analyzeProject(
              args["project"]);
        case "check_imports":
          return await LspService.checkImports(
              args["project"], args["file_path"]);
        // Multi-agent
        case "delegate_task":
          return await SubAgentService.delegate(
              args["agent_type"], args["task"]);
        case "snapshot_undo":
          return await SnapshotService.undo(
              args["project"], args["file_path"]);
        case "snapshot_undo_all":
          return await SnapshotService.undoAll(
              args["project"]);
        case "format_code":
          return await FormatterService.format(
              args["project"], args["file_path"]);
        case "batch_execute":
          return await _batchExecute(args["calls"] as List);
        case "mcp_call":
          return await McpClient.quickCall(
              url: args["url"],
              tool: args["tool"],
              args: Map<String, dynamic>.from(
                  args["args"] ?? {}));
        case "diff_preview":
          return await DiffService.previewEdit(
              args["project"], args["file_path"],
              args["old_string"], args["new_string"]);
        case "create_plan":
          return ExecutionPlanService.createPlan(
              args["task"], {});
        case "self_review":
          if (args["file_path"] != null) {
            return await SelfReviewService.quickCheck(
                args["project"], args["file_path"]);
          }
          if (gitService != null) {
            return await SelfReviewService.reviewBeforeCommit(
                args["project"], gitService!);
          }
          return "Git not configured for self-review.";
        case "project_summary":
          return await ProjectOnboarding.summarize(
              args["project"]);
        case "security_scan":
          return await SecurityScanService.scanProject(
              args["project"]);
        case "api_test":
          if (args["method"] == "POST") {
            return await ApiTester.post(
                args["url"], args["body"] ?? "{}",
                headers: args["headers"]?.cast<String, String>());
          }
          return await ApiTester.get(args["url"],
              headers: args["headers"]?.cast<String, String>());
        case "debate":
          return await DebateService.debate(
              args["topic"], args["agent1"], args["agent2"]);
        case "create_pr":
          return await GitHubService.createPR(
              args["owner"], args["repo"],
              args["title"], args["body"],
              head: args["head"] ?? "master",
              base: args["base"] ?? "main");
        case "run_code":
          return await CodeSandbox.run(
              args["project"], args["code"],
              language: args["language"]);
        case "check_deps":
          return await DependencyUpdater.check(
              args["project"]);
        case "analyze_function":
          return await InteractiveDebugger.analyzeFunction(
              args["project"], args["file_path"],
              args["function_name"]);
        case "detect_conflicts":
          return await MergeConflictResolver.detect(
              args["project"]);
        case "profile_performance":
          if (args["file_path"] != null) {
            return await PerformanceProfiler.analyzeFile(
                args["project"], args["file_path"]);
          }
          return await PerformanceProfiler.profileProject(
              args["project"]);
        case "daily_standup":
          if (gitService != null) {
            return await DailyStandupService.generate(
                args["project"], gitService!);
          }
          return "Git not configured.";
        // Deployment
        case "check_deploy_readiness":
          return await DeploymentService
              .checkDeployReadiness(args["project"]);
        case "generate_docker_compose":
          return DeploymentService.generateDockerCompose(
              args["stack"],
              Map<String, String>.from(
                  args["config"] ?? {}));
        case "generate_ci_config":
          return DeploymentService.generateCIConfig(
              args["platform"],
              nodeVersion: args["node_version"],
              pythonVersion: args["python_version"]);
        // Code generation
        case "generate_test_template":
          return await CodeGenerationService
              .generateTestTemplate(args["project"],
                  args["source_file"]);
        case "generate_boilerplate":
          return CodeGenerationService.generateBoilerplate(
              args["project_type"], args["name"]);
        case "suggest_optimizations":
          return CodeGenerationService
              .suggestOptimizations(args["code"]);
        // Project management
        case "estimate_effort":
          return DocumentationService.estimateEffort(
              args["description"]);
        case "generate_readme":
          return DocumentationService.generateReadmeTemplate(
              args["project_name"],
              args["description"],
              args["tech_stack"]);
        case "generate_api_docs":
          return await DocumentationService
              .generateApiDocs(args["project"],
                  args["source_file"]);
        default:
          return "Error: Unknown tool '$name'. Available tools: read_file, write_file, edit_file, list_files, glob_files, search_code, delete_file, run_command, git_sync, git_status, web_search, web_fetch, browser_open, browser_extract, browser_follow, sql_detect, sql_query, sql_schema, github_list_issues, github_create_issue, github_list_prs, github_get_pr, github_search_code, github_get_file, github_get_repo, diagnose_file, analyze_project, check_imports, find_patterns, suggest_tests, suggest_optimizations, generate_test_template, generate_boilerplate, impact_analysis, delegate_task, estimate_effort, generate_readme, generate_api_docs, check_deploy_readiness, generate_docker_compose, generate_ci_config, create_tasks, ask_user.";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<String> _runShellCommand(
      String project, String command,
      [String? cwd]) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? "cmd" : "sh",
        [
          Platform.isWindows ? "/c" : "-c",
          command,
        ],
        workingDirectory: cwd != null
            ? "${StorageService.projectsRoot.path}/$project/$cwd"
            : "${StorageService.projectsRoot.path}/$project",
        runInShell: true,
      );
      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      if (out.isEmpty && err.isEmpty) {
        return "(completed, no output)";
      }
      if (err.isNotEmpty && out.isEmpty) {
        return err;
      }
      if (err.isNotEmpty) {
        return "$out\n$err";
      }
      return out;
    } catch (e) {
      return "Command failed: $e";
    }
  }

  Future<String> _globSearch(
      String project, String pattern) async {
    final results = <String>[];
    final regex = _globToRegex(pattern);

    Future<void> scanDir(String path) async {
      final entries =
          await StorageService.listDir(project, path);
      for (final entry in entries) {
        final name = entry.uri.pathSegments.last;
        final fullPath =
            path.isEmpty ? name : "$path/$name";
        if (name.startsWith(".") &&
            name != ".gitignore") continue;
        if (entry is Directory) {
          if (name != "node_modules" &&
              name != "dist" &&
              name != ".git") {
            await scanDir(fullPath);
          }
        } else {
          if (regex.hasMatch(fullPath)) {
            results.add(fullPath);
            if (results.length >= 50) return;
          }
        }
      }
    }

    await scanDir("");
    return results.isEmpty
        ? "No files matched $pattern"
        : results.join("\n");
  }

  static RegExp _globToRegex(String pattern) {
    var escaped = RegExp.escape(pattern);
    escaped = escaped.replaceAll(r'\*\*', '<<DEEP>>');
    escaped = escaped.replaceAll(r'\*', r'[^/]*');
    escaped = escaped.replaceAll('<<DEEP>>', '.*');
    return RegExp('^$escaped\$');
  }

  Future<String> _suggestTests(
      String project, String filePath) async {
    try {
      final content =
          await StorageService.readFile(project, filePath);
      final buf = StringBuffer();
      buf.writeln("## Test suggestions for $filePath\n");
      buf.writeln("Based on code analysis:\n");

      // Find function/method definitions
      final funcRegex = RegExp(
          r'(?:function|def|async\s+function|export\s+(?:async\s+)?function|const\s+\w+\s*=\s*(?:async\s*)?\(|static\s+(?:async\s*)?\w+\s*\()\s*(\w+)',
          multiLine: true);

      final funcs = funcRegex.allMatches(content).toList();
      if (funcs.isEmpty) {
        buf.writeln("No testable functions found.");
        return buf.toString();
      }

      for (final m in funcs.take(8)) {
        final name = m.group(1) ?? "unknown";
        buf.writeln("### $name");
        buf.writeln("- [ ] Test happy path with valid input");
        buf.writeln("- [ ] Test with null/undefined input");
        buf.writeln("- [ ] Test with empty/zero input");
        buf.writeln("- [ ] Test error handling path");
        buf.writeln();
      }

      buf.writeln(
          "Match the project's existing test framework and patterns.");
      return buf.toString();
    } catch (e) {
      return "Cannot analyze file: $e";
    }
  }

  Future<String> _batchExecute(
      List<dynamic> calls) async {
    final futures = calls.map((c) async {
      final tool = c["tool"] as String;
      final args =
          Map<String, dynamic>.from(c["args"] ?? {});
      final r = await _executeTool(tool, args);
      return "$tool: $r";
    });
    final results = await Future.wait(futures);
    return results.join("\n\n");
  }

  Future<String> _editFile(String project, String path,
      String oldStr, String newStr) async {
    try {
      final content =
          await StorageService.readFile(project, path);
      if (!content.contains(oldStr)) {
        return "Error: old_string not found in $path. Read the file first to get the exact text.";
      }
      final updated = content.replaceFirst(oldStr, newStr);
      await StorageService.writeFile(
          project, path, updated);
      return "Edited $path — 1 replacement made";
    } catch (e) {
      return "Edit failed: $e";
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

    maybeCompress();

    int loopCount = 0;
    const maxLoops = 20;

    while (loopCount < maxLoops) {
      loopCount++;
      if (loopCount == maxLoops) {
        yield "\n(Max steps reached — task may be incomplete. Try breaking it into smaller steps.)\n";
      }

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
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        final msg = switch (response.statusCode) {
          401 => "Invalid API key. Check your DeepSeek key in Settings.",
          429 => "Rate limited. Wait a moment and try again.",
          503 => "DeepSeek is temporarily unavailable. Try again later.",
          _ => "API Error (${response.statusCode})",
        };
        yield msg;
        return;
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body);
      } catch (_) {
        yield "Invalid response from API. Try again.";
        return;
      }

      final choices = json["choices"] as List?;
      if (choices == null || choices.isEmpty) {
        yield "Empty response from API. The model may be overloaded.";
        return;
      }

      final choice = choices[0] as Map<String, dynamic>?;
      if (choice == null) {
        yield "Malformed response from API.";
        return;
      }

      final msg = choice["message"] as Map<String, dynamic>?;
      if (msg == null) {
        yield "No message in API response.";
        return;
      }

      final content = msg["content"];
      if (content is String && content.isNotEmpty) {
        yield content;
      }

      if (msg["tool_calls"] is List && (msg["tool_calls"] as List).isNotEmpty) {
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
          onToolCall?.call(toolName, preview);

          final result =
              await _executeTool(toolName, toolArgs);

          onToolResult?.call(toolName, preview, result);

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

    await saveSession();
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
