import "dart:convert";
import "dart:io";
import "package:http/http.dart" as http;
import "storage_service.dart";
import "git_service.dart";
import "../models/message.dart";
import "settings_service.dart";

class AgentService {
  static const String _apiUrl =
      "https://api.deepseek.com/v1/chat/completions";

  final String projectName;
  GitService? gitService;
  final List<Message> messages = [];

  AgentService({required this.projectName}) {
    messages.add(Message(role: "system", content: _systemPrompt));
  }

  void setGitService(GitService gs) {
    gitService = gs;
  }

  static String get _systemPrompt {
    return """
You are OpenCode Mobile - an AI coding agent running on Android.
You write code, debug, review, explain, and manage projects.

## Tools
- read_file(project, path) - read a file
- write_file(project, path, content) - create/overwrite a file
- list_files(project, path?) - browse directory
- delete_file(project, path) - delete a file
- search_code(project, pattern, fileExt?) - search text in files
- git_sync(project, message) - commit and push to GitHub
- git_status(project) - check changed files

## Code Rules
- No try/catch unless unavoidable. No 'any' in TypeScript.
- Early returns over else. const over let.
- Functions < 50 lines. Files < 300 lines.
- Handle edge cases: null, empty, wrong-type input.
- Error messages: what failed + why + how to fix.
- No secrets in code.

## TypeScript: discriminated unions, satisfies, no type assertions.
## Python: type hints, dataclasses, f-strings, context managers.
## SQL: explicit columns, parameterized queries, snake_case.
## API: REST nouns, semantic status codes.

## Workflow
1. Read files before editing.
2. search_code to find patterns. list_files to browse.
3. Write minimal version first.
4. git_sync after each logical unit. Meaningful commits.
5. Be concise. Output result. No fluff.
""";
  }

  static List<Map<String, dynamic>> get _tools {
    return [
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
              "Search for text patterns in project files",
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
              "Commit changes and push to GitHub",
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
    ];
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
          if (entries.isEmpty) {
            return "(empty directory)";
          }
          return entries.map((e) {
            final name = e.uri.pathSegments.last;
            return e is Directory ? "[DIR] $name" : name;
          }).join("\n");
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
          if (gs == null) {
            return "Git not configured";
          }
          return await gs.commitAndPush(args["message"]);
        case "git_status":
          final gs = gitService;
          if (gs == null) {
            return "Git not configured";
          }
          return await gs.getStatus();
        default:
          return "Unknown tool: $name";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  Stream<String> sendMessage(String userMessage) async* {
    messages.add(Message(role: "user", content: userMessage));

    var loopCount = 0;
    const maxLoops = 15;

    while (loopCount < maxLoops) {
      loopCount++;

      final body = jsonEncode({
        "model": "deepseek-chat",
        "messages": messages.map((m) => m.toJson()).toList(),
        "tools": _tools,
        "temperature": 0.2,
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
          yield "\n[TOOL] $toolName($preview)\n";

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
  }

  void reset() {
    messages.clear();
    messages.add(Message(role: "system", content: _systemPrompt));
  }
}
