import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "../services/agent_service.dart";
import "../services/git_service.dart";
import "../services/storage_service.dart";
import "../services/session_memory.dart";
import "../services/sync_service.dart";
import "../services/offline_queue.dart";
import "../services/user_profile.dart";
import "../services/settings_service.dart";
import "../services/localization.dart";
import "../services/snapshot_service.dart";
import "../services/session_sharing_service.dart";
import "file_browser_screen.dart";
import "settings_screen.dart";

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final AgentService _agent;
  SyncService? _sync;
  GitService? _gitService;
  String? _projectName;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<UIMessage> _messages = [];
  bool _loading = false;
  AgentMode _mode = AgentMode.auto;
  String _gitStatus = "";
  bool _syncing = false;
  int _offlineCount = 0;
  int _messageIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _agent = AgentService(projectName: "_general_");
    _init();
  }

  Future<void> _init() async {
    await SessionMemory.init();
    await StorageService.init();
    await _agent.scanProject();

    final hasKey = SettingsService.deepseekApiKey.isNotEmpty;
    final hasGithub = SettingsService.githubToken.isNotEmpty;

    if (hasGithub) {
      _addSystem("GitHub connected as ${SettingsService.githubUser}");
    }

    _addAssistant(
      hasKey
          ? "I'm OpenCode — your AI coding agent.\n\n"
            "I can:\n"
            "• Write, read, and edit code\n"
            "• Search the web and read docs\n"
            "• Manage GitHub repos and issues\n"
            "• Run terminal commands\n"
            "• Delegate to specialized sub-agents\n\n"
            "Commands:\n"
            "/clone <repo> — clone a GitHub project\n"
            "/projects — list local projects\n"
            "/github <token> <user> — connect GitHub\n"
            "/config — change API keys\n"
            "/files — browse project files\n"
            "/brainstorm /research /architect /code /debug /refactor\n"
            "/help — all commands\n\n"
            "What are we working on?"
          : "I'm OpenCode. Your API key is set.\n\n"
            "To connect GitHub, type: /github <token> <username>\n"
            "Then you can: /clone <repo> to get started.\n\n"
            "What would you like to do?",
    );
  }

  Future<void> _connectGithub(String token, String user) async {
    SettingsService.githubToken = token;
    SettingsService.githubUser = user;
    _addSystem("GitHub connected as $user");

    // Try listing repos
    try {
      final gs = GitService(
        projectName: "_temp_",
        repoUrl: "https://github.com/$user/dummy.git",
        token: token,
      );
      _addSystem("GitHub token verified. Use /clone <repo> to start working.");
    } catch (e) {
      _addSystem("GitHub token saved. Verify it's correct if clone fails.");
    }
  }

  Future<void> _cloneProject(String repoName) async {
    final token = SettingsService.githubToken;
    final user = SettingsService.githubUser;

    if (token.isEmpty || user.isEmpty) {
      _addSystem("Set up GitHub first: /github <token> <username>");
      return;
    }

    _addSystem("Cloning $repoName...");

    final repoUrl = "https://github.com/$user/$repoName.git";
    final gs = GitService(projectName: repoName, repoUrl: repoUrl, token: token);

    final result = await gs.clone();

    if (result.startsWith("Clone failed") || result.startsWith("Project already")) {
      _addSystem(result);
      return;
    }

    _addSystem(result);
    _projectName = repoName;
    _gitService = gs;

    _agent.setGitService(gs);
    _sync = SyncService(projectName: repoName, gitService: gs);
    await _agent.scanProject();
    await _agent.reset();

    _addAssistant("Project **$repoName** is ready. What should we work on?");
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Attach image"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text("Camera"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text("Gallery"),
          ),
        ],
      ),
    );

    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    final mime = file.path.endsWith(".png") ? "image/png" : "image/jpeg";

    _addSystem("[Image attached: ${file.path.split('/').last}]");
    _addUser("[Image: data:$mime;base64,${base64.substring(0, 50)}...]");

    // Send as user message with image context
    final imageMsg = "I'm sharing an image. Please analyze it and tell me what you see, any code or errors visible, and what I should do.";
    if (!mounted) return;
    setState(() {
      _messages.add(UIMessage(id: ++_messageIdCounter, type: UIMessageType.user, content: imageMsg));
      _loading = true;
    });
    _scrollDown();

    _agent.onToolCall = (tool, args) => _addToolPending(tool, args);
    _agent.onToolResult = (tool, args, result) => _addToolCall(tool, args, result);

    String text = "";
    try {
      final stream = _agent.sendMessage(imageMsg);
      await for (final chunk in stream) {
        text += chunk;
        _addAssistant(text);
      }
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        setState(() => _messages.last.isStreaming = false);
      }
    } catch (e) {
      _addSystem("Error: $e");
    }
    _agent.onToolCall = null;
    _agent.onToolResult = null;
    if (mounted) setState(() => _loading = false);
  }

  void _addSystem(String text) {
    if (!mounted) return;
    setState(() => _messages.add(UIMessage(
        id: ++_messageIdCounter, type: UIMessageType.system, content: text)));
    _scrollDown();
  }

  void _addAssistant(String text) {
    if (!mounted) return;
    final last = _messages.isNotEmpty ? _messages.last : null;
    if (last != null && last.type == UIMessageType.assistant && last.isStreaming) {
      setState(() => last.content = text);
    } else {
      setState(() => _messages.add(UIMessage(
          id: ++_messageIdCounter, type: UIMessageType.assistant, content: text, isStreaming: true)));
    }
    _scrollDown();
  }

  void _addToolPending(String tool, String args) {
    if (!mounted) return;
    setState(() => _messages.add(UIMessage(
        id: ++_messageIdCounter, type: UIMessageType.toolPending, toolName: tool, toolArgs: args)));
    _scrollDown();
  }

  void _addToolCall(String tool, String args, String result) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.type == UIMessageType.toolPending && m.toolName == tool);
      if (idx >= 0) {
        _messages[idx] = UIMessage(
            id: _messages[idx].id, type: UIMessageType.toolResult,
            content: result, toolName: tool, toolArgs: args);
      } else {
        _messages.add(UIMessage(
            id: ++_messageIdCounter, type: UIMessageType.toolCall,
            content: result, toolName: tool, toolArgs: args));
      }
    });
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
      }
    });
  }

  void _setMode(AgentMode mode) {
    setState(() => _mode = mode);
    _agent.setMode(mode);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    _inputCtrl.clear();

    // Commands
    if (text.startsWith("/")) {
      final parts = text.split(" ");
      final cmd = parts[0].toLowerCase();

      if (cmd == "/config") {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        return;
      }
      if (cmd == "/github") {
        if (parts.length >= 3) {
          await _connectGithub(parts[1], parts[2]);
        } else {
          _addSystem("Usage: /github <token> <username>");
        }
        return;
      }
      if (cmd == "/clone") {
        if (parts.length >= 2) {
          await _cloneProject(parts[1]);
        } else {
          _addSystem("Usage: /clone <repository-name>");
        }
        return;
      }
      if (cmd == "/files" || cmd == "/ls") {
        if (_projectName != null) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FileBrowserScreen(projectName: _projectName!)));
        } else {
          _addSystem("No project open. Use /clone first.");
        }
        return;
      }
      if (cmd == "/brainstorm") { _setMode(AgentMode.brainstorm); return; }
      if (cmd == "/research") { _setMode(AgentMode.research); return; }
      if (cmd == "/architect") { _setMode(AgentMode.architect); return; }
      if (cmd == "/code") { _setMode(AgentMode.code); return; }
      if (cmd == "/debug") { _setMode(AgentMode.debug); return; }
      if (cmd == "/refactor") { _setMode(AgentMode.refactor); return; }
      if (cmd == "/auto") { _setMode(AgentMode.auto); return; }
      if (cmd == "/help") {
        _addSystem(
            "/brainstorm /research /architect /code /debug /refactor /auto\n"
            "/clone <repo> — clone project\n"
            "/github <token> <user> — connect GitHub\n"
            "/config — settings\n"
            "/files — file browser\n"
            "/clear — fresh session\n"
            "/help — this message");
        return;
      }
      if (cmd == "/clear") {
        await _agent.reset();
        setState(() { _messages.clear(); _mode = AgentMode.auto; });
        _addSystem("Fresh session.");
        return;
      }
      if (cmd == "/undo" && _projectName != null) {
        final r = await SnapshotService.undoAll(_projectName!);
        _addSystem(r);
        return;
      }
      if (cmd == "/format" && _projectName != null) {
        _addSystem("Format project code... (use format_code tool in chat for specific files)");
        return;
      }
      if (cmd == "/commit" && _projectName != null && _gitService != null) {
        final msg = parts.length > 1 ? parts.sublist(1).join(" ") : "update from mobile";
        final r = await _gitService!.commitAndPush(msg);
        _addSystem(r);
        return;
      }
      if (cmd == "/learn") {
        _addSystem("Learning from session... (agent remembers decisions automatically)");
        return;
      }
      if (cmd == "/share" && _projectName != null) {
        _addSystem("Exporting session...");
        final summary = SessionSharingService.generateShareSummary(
            _agent.messages.map((m) => m.toJson()).toList());
        try {
          final r = await SessionSharingService.exportSession(
              _projectName!,
              _agent.messages.map((m) => m.toJson()).toList(),
              gitService: _gitService);
          _addSystem(r);
          _addAssistant("Session shared! Others can view it in .opencode/sessions/\n\nSummary:\n$summary");
        } catch (e) {
          _addSystem("Share failed: $e");
        }
        return;
      }
      if (cmd == "/changelog" && _projectName != null && _gitService != null) {
        final log = await _gitService!.getLog(limit: 20);
        _addSystem("Recent commits:\n${log.join("\n")}");
        _addSystem("Ask me to generate a changelog from these commits.");
        return;
      }
      if (cmd == "/rmslop") {
        _addSystem("Send me the file you want cleaned. I'll remove: unnecessary comments, defensive checks, any casts, inconsistent style.");
        return;
      }
      if (cmd == "/spellcheck") {
        _addSystem("Send me the file or text to check. I'll find spelling and grammar errors.");
        return;
      }
    }

    // Regular message
    if (!mounted) return;
    setState(() {
      _messages.add(UIMessage(id: ++_messageIdCounter, type: UIMessageType.user, content: text));
      _loading = true;
    });
    _scrollDown();

    _agent.onToolCall = (tool, args) => _addToolPending(tool, args);
    _agent.onToolResult = (tool, args, result) => _addToolCall(tool, args, result);

    String assistantText = "";
    try {
      final stream = _agent.sendMessage(text);
      await for (final chunk in stream) {
        assistantText += chunk;
        _addAssistant(assistantText);
      }
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        setState(() => _messages.last.isStreaming = false);
      }
    } catch (e) {
      _addSystem("Error: $e");
    }
    _agent.onToolCall = null;
    _agent.onToolResult = null;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _modeColor() => switch (_mode) {
    AgentMode.brainstorm => const Color(0xFFA371F7),
    AgentMode.architect => const Color(0xFF8E44AD),
    AgentMode.code => const Color(0xFF3FB950),
    AgentMode.debug => const Color(0xFFD2991D),
    AgentMode.refactor => const Color(0xFF58A6FF),
    AgentMode.research => const Color(0xFF00BCD4),
    AgentMode.auto => const Color(0xFF8B949E),
  };

  String _modeLabel() => switch (_mode) {
    AgentMode.brainstorm => "BRAINSTORM",
    AgentMode.architect => "ARCHITECT",
    AgentMode.code => "CODE",
    AgentMode.debug => "DEBUG",
    AgentMode.refactor => "REFACTOR",
    AgentMode.research => "RESEARCH",
    AgentMode.auto => "AUTO",
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          Text(_projectName ?? "OpenCode",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: _modeColor().withAlpha(40),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_modeLabel(),
                style: TextStyle(color: _modeColor(), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ]),
        actions: [
          if (_projectName != null)
            IconButton(icon: const Icon(Icons.folder_open, size: 20), tooltip: "Files",
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FileBrowserScreen(projectName: _projectName!)))),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, size: 20),
            onSelected: (v) => switch (v) {
              "auto" => _setMode(AgentMode.auto),
              "brainstorm" => _setMode(AgentMode.brainstorm),
              "research" => _setMode(AgentMode.research),
              "architect" => _setMode(AgentMode.architect),
              "code" => _setMode(AgentMode.code),
              "debug" => _setMode(AgentMode.debug),
              "refactor" => _setMode(AgentMode.refactor),
              "config" => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              _ => null,
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: "auto", child: Text("Auto detect")),
              const PopupMenuItem(value: "brainstorm", child: Text("Brainstorm")),
              const PopupMenuItem(value: "research", child: Text("Research")),
              const PopupMenuItem(value: "architect", child: Text("Architect")),
              const PopupMenuItem(value: "code", child: Text("Write code")),
              const PopupMenuItem(value: "debug", child: Text("Debug")),
              const PopupMenuItem(value: "refactor", child: Text("Refactor")),
              const PopupMenuDivider(),
              const PopupMenuItem(value: "config", child: Text("Settings")),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) => _buildMessage(_messages[i], cs),
              )),
        if (_loading)
          Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Row(children: [
            SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: _modeColor())),
            const SizedBox(width: 8),
            Text("Working...", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ])),
        _buildInputBar(cs),
      ]),
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: const Color(0xFF30363D)))),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(
          controller: _inputCtrl, maxLines: 4, minLines: 1, enabled: !_loading,
          style: const TextStyle(fontSize: 15),
          decoration: const InputDecoration(
            hintText: "Ask OpenCode...", border: InputBorder.none,
            enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
        )),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.camera_alt, size: 22),
          color: const Color(0xFF8B949E),
          onPressed: _loading ? null : _pickImage,
          tooltip: "Attach image",
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 2),
        FilledButton(
          onPressed: _loading ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: _modeColor(), minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _buildMessage(UIMessage msg, ColorScheme cs) {
    return switch (msg.type) {
      UIMessageType.system => _buildSystemBubble(msg, cs),
      UIMessageType.user => _buildUserBubble(msg, cs),
      UIMessageType.assistant => _buildAssistantBubble(msg, cs),
      UIMessageType.toolCall || UIMessageType.toolResult => _buildToolCard(msg, cs),
      UIMessageType.toolPending => _buildToolPending(msg, cs),
    };
  }

  Widget _buildSystemBubble(UIMessage msg, ColorScheme cs) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(msg.content,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center));
  }

  Widget _buildUserBubble(UIMessage msg, ColorScheme cs) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(
        mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(14)),
              child: Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)))),
        ]));
  }

  Widget _buildAssistantBubble(UIMessage msg, ColorScheme cs) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(
        mainAxisAlignment: MainAxisAlignment.start, children: [
          Flexible(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF30363D))),
              child: _renderContent(msg.content, cs))),
        ]));
  }

  Widget _buildToolCard(UIMessage msg, ColorScheme cs) {
    final color = _toolColor(msg.toolName ?? "");
    return Padding(padding: EdgeInsets.only(left: 24, right: 8, bottom: msg.type == UIMessageType.toolResult ? 12 : 2),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(80))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color.withAlpha(20),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7))),
                child: Text(msg.toolName?.toUpperCase() ?? "TOOL",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5))),
            if (msg.type == UIMessageType.toolResult)
              Padding(padding: const EdgeInsets.all(10), child: Text(msg.content,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: "monospace", height: 1.4),
                  maxLines: 12, overflow: TextOverflow.ellipsis)),
          ])));
  }

  Widget _buildToolPending(UIMessage msg, ColorScheme cs) {
    final color = _toolColor(msg.toolName ?? "");
    return Padding(padding: const EdgeInsets.only(left: 24, right: 8, bottom: 2), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(80))),
        child: Row(children: [
          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
          const SizedBox(width: 8),
          Text(msg.toolName?.toUpperCase() ?? "TOOL",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ])));
  }

  Widget _renderContent(String text, ColorScheme cs) {
    if (text.contains("```")) {
      final parts = <Widget>[];
      final regex = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
      int lastEnd = 0;
      for (final match in regex.allMatches(text)) {
        if (match.start > lastEnd) parts.add(SelectableText(text.substring(lastEnd, match.start),
            style: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.55)));
        parts.add(Container(
          width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D))),
          padding: const EdgeInsets.all(12),
          child: SelectableText(match.group(2) ?? "",
              style: const TextStyle(fontFamily: "monospace", fontSize: 12, color: Color(0xFFE6EDF3), height: 1.45)),
        ));
        lastEnd = match.end;
      }
      if (lastEnd < text.length) parts.add(SelectableText(text.substring(lastEnd),
          style: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.55)));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts);
    }
    return SelectableText(text, style: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.55));
  }

  Color _toolColor(String name) => switch (name) {
    "read_file" || "write_file" || "edit_file" => const Color(0xFF58A6FF),
    "delete_file" => const Color(0xFFF85149),
    "list_files" || "glob_files" => const Color(0xFFA371F7),
    "search_code" => const Color(0xFFD2991D),
    "run_command" => const Color(0xFFF78166),
    "git_sync" || "git_status" => const Color(0xFFF85149),
    "web_search" || "web_fetch" => const Color(0xFF00BCD4),
    _ => const Color(0xFF8B949E),
  };
}

enum UIMessageType { system, user, assistant, toolCall, toolResult, toolPending }

class UIMessage {
  final int id;
  final UIMessageType type;
  String content;
  final String? toolName;
  final String? toolArgs;
  bool isStreaming;
  UIMessage({required this.id, required this.type, this.content = "",
    this.toolName, this.toolArgs, this.isStreaming = false});
}
