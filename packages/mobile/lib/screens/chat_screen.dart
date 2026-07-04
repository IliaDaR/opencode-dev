import "dart:async";
import "package:flutter/material.dart";
import "../services/agent_service.dart";
import "../services/git_service.dart";
import "../services/storage_service.dart";
import "../services/session_memory.dart";
import "../services/sync_service.dart";
import "../services/offline_queue.dart";
import "../services/user_profile.dart";
import "file_browser_screen.dart";

class ChatScreen extends StatefulWidget {
  final String projectName;
  final GitService gitService;
  const ChatScreen({
    super.key,
    required this.projectName,
    required this.gitService,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final AgentService _agent;
  late final SyncService _sync;
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
    _agent = AgentService(projectName: widget.projectName);
    _agent.setGitService(widget.gitService);
    _sync = SyncService(
        projectName: widget.projectName,
        gitService: widget.gitService);
    _init();
  }

  Future<void> _init() async {
    _addSystem("Syncing with GitHub...");
    await SessionMemory.init();
    setState(() => _syncing = true);
    final sr = await _sync.pullConfig();
    setState(() => _syncing = false);
    if (sr.messages.isNotEmpty) _addSystem(sr.messages.first);

    await _agent.scanProject();
    UserProfile.recordSession();
    UserProfile.learnFromProject(widget.projectName);
    final hasSession = await _agent.loadSession();

    if (hasSession) {
      _addSystem("Session restored");
      for (final m in _agent.messages) {
        if (m.role == "user") _addUser(m.content);
        if (m.role == "assistant" && m.content.isNotEmpty) {
          _addAssistant(m.content);
        }
      }
    } else {
      await _agent.reset();
      _addAssistant(
          "${widget.projectName} loaded. What should we work on?\n\n"
          "Commands: /brainstorm /architect /code /debug /refactor /research");
    }

    try {
      final s = await widget.gitService.getStatus();
      _gitStatus = s;
      if (s != "No changes" && s != "Not a git repository") {
        _addSystem("Uncommitted changes detected");
      }
    } catch (_) {}

    _offlineCount =
        await OfflineQueue.pendingCount(widget.projectName);
    if (_offlineCount > 0) {
      _addSystem("$_offlineCount offline actions pending");
    }
  }

  void _addSystem(String text) {
    if (!mounted) return;
    setState(() => _messages.add(UIMessage(
        id: ++_messageIdCounter,
        type: UIMessageType.system,
        content: text)));
    _scrollDown();
  }

  void _addUser(String text) {
    if (!mounted) return;
    setState(() => _messages.add(UIMessage(
        id: ++_messageIdCounter,
        type: UIMessageType.user,
        content: text)));
    _scrollDown();
  }

  void _addAssistant(String text) {
    if (!mounted) return;
    final last = _messages.isNotEmpty ? _messages.last : null;
    if (last != null &&
        last.type == UIMessageType.assistant &&
        last.isStreaming) {
      setState(() => last.content = text);
    } else {
      setState(() => _messages.add(UIMessage(
          id: ++_messageIdCounter,
          type: UIMessageType.assistant,
          content: text,
          isStreaming: true)));
    }
    _scrollDown();
  }

  void _addToolCall(String tool, String args, String result) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) =>
          m.type == UIMessageType.toolPending && m.toolName == tool);
      if (idx >= 0) {
        _messages[idx] = UIMessage(
            id: _messages[idx].id,
            type: UIMessageType.toolResult,
            content: result,
            toolName: tool,
            toolArgs: args);
      } else {
        _messages.add(UIMessage(
            id: ++_messageIdCounter,
            type: UIMessageType.toolCall,
            content: result,
            toolName: tool,
            toolArgs: args));
      }
    });
    _scrollDown();
  }

  void _addToolPending(String tool, String args) {
    if (!mounted) return;
    setState(() => _messages.add(UIMessage(
        id: ++_messageIdCounter,
        type: UIMessageType.toolPending,
        toolName: tool,
        toolArgs: args)));
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut);
      }
    });
  }

  void _setMode(AgentMode mode) {
    setState(() => _mode = mode);
    _agent.setMode(mode);
    _addSystem("Mode: ${mode.name.toUpperCase()}");
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    _inputCtrl.clear();

    if (text.startsWith("/")) {
      final cmd = text.toLowerCase();
      if (cmd == "/brainstorm") {
        _setMode(AgentMode.brainstorm);
        return;
      }
      if (cmd == "/research") {
        _setMode(AgentMode.research);
        return;
      }
      if (cmd == "/architect") {
        _setMode(AgentMode.architect);
        return;
      }
      if (cmd == "/code") {
        _setMode(AgentMode.code);
        return;
      }
      if (cmd == "/debug") {
        _setMode(AgentMode.debug);
        return;
      }
      if (cmd == "/refactor") {
        _setMode(AgentMode.refactor);
        return;
      }
      if (cmd == "/auto") {
        _setMode(AgentMode.auto);
        return;
      }
      if (cmd == "/files" || cmd == "/ls") {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FileBrowserScreen(
              projectName: widget.projectName),
        ));
        return;
      }
      if (cmd == "/git" || cmd == "/status") {
        final s = await widget.gitService.getStatus();
        _gitStatus = s;
        _addSystem(s);
        return;
      }
      if (cmd == "/sync") {
        setState(() => _syncing = true);
        final r = await _sync.pushChanges("manual sync");
        setState(() => _syncing = false);
        _addSystem(
            r.success ? "Synced" : "Sync failed");
        return;
      }
      if (cmd == "/clear") {
        await SessionMemory.clearMemory(
            widget.projectName);
        await _agent.reset();
        setState(() {
          _messages.clear();
          _mode = AgentMode.auto;
        });
        _addSystem("Memory cleared. Fresh session.");
        return;
      }
      if (cmd == "/help") {
        _addSystem(
            "/brainstorm /research /architect /code /debug /refactor /auto\n"
            "/files — file browser  /git — status  /sync — push to GitHub\n"
            "/clear — reset  /help — this");
        return;
      }
    }

    _addUser(text);
    setState(() => _loading = true);

    _agent.onToolCall = (tool, args) {
      _addToolPending(tool, args);
    };
    _agent.onToolResult = (tool, args, result) {
      _addToolCall(tool, args, result);
    };

    String assistantText = "";
    try {
      final stream = _agent.sendMessage(text);
      await for (final chunk in stream) {
        assistantText += chunk;
        _addAssistant(assistantText);
      }
      final last =
          _messages.isNotEmpty ? _messages.last : null;
      if (last != null && last.isStreaming) {
        setState(() => last.isStreaming = false);
      }
      _gitStatus =
          await widget.gitService.getStatus();
    } catch (e) {
      _addSystem("Error: $e");
      await OfflineQueue.enqueue(
          widget.projectName, "send_message",
          data: {"text": text});
      setState(() => _offlineCount++);
    }
    _agent.onToolCall = null;
    _agent.onToolResult = null;
    setState(() => _loading = false);
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
          Text(widget.projectName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: _modeColor().withAlpha(40),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_modeLabel(),
                style: TextStyle(
                    color: _modeColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
        ]),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2)),
            ),
          if (_offlineCount > 0)
            IconButton(
              icon: Stack(children: [
                const Icon(Icons.cloud_off, size: 20),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2991D),
                      borderRadius:
                          BorderRadius.circular(6),
                    ),
                    child: Text("$_offlineCount",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight:
                                FontWeight.bold)),
                  ),
                ),
              ]),
              tooltip: "Offline queue",
              onPressed: () => _addSystem(
                  "$_offlineCount pending actions"),
            ),
          if (_gitStatus.isNotEmpty &&
              _gitStatus != "No changes")
            IconButton(
              icon: const Icon(Icons.call_split,
                  size: 20),
              tooltip: _gitStatus,
              onPressed: () =>
                  _addSystem(_gitStatus),
            ),
          IconButton(
            icon: const Icon(Icons.folder_open,
                size: 20),
            tooltip: "Files",
            onPressed: () =>
                Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FileBrowserScreen(
                        projectName:
                            widget.projectName),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, size: 20),
            onSelected: (v) => switch (v) {
                  "auto" =>
                    _setMode(AgentMode.auto),
                  "brainstorm" =>
                    _setMode(AgentMode.brainstorm),
                  "architect" =>
                    _setMode(AgentMode.architect),
                  "code" =>
                    _setMode(AgentMode.code),
                  "debug" =>
                    _setMode(AgentMode.debug),
                  "refactor" =>
                    _setMode(AgentMode.refactor),
                  "research" =>
                    _setMode(AgentMode.research),
                  "sync" => () async {
                      setState(() =>
                          _syncing = true);
                      await _sync.pushChanges(
                          "manual sync");
                      setState(() =>
                          _syncing = false);
                    }(),
                  _ => null,
                },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: "auto",
                  child: Text("Auto detect")),
              const PopupMenuItem(
                  value: "brainstorm",
                  child: Text("Brainstorm")),
              const PopupMenuItem(
                  value: "research",
                  child: Text("Research")),
              const PopupMenuItem(
                  value: "architect",
                  child: Text("Architect")),
              const PopupMenuItem(
                  value: "code",
                  child: Text("Write code")),
              const PopupMenuItem(
                  value: "debug",
                  child: Text("Debug")),
              const PopupMenuItem(
                  value: "refactor",
                  child: Text("Refactor")),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: "sync",
                  child: Text("Sync with PC")),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48,
                          color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text("OpenCode Mobile",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  cs.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                          "AI coding agent on Android",
                          style: TextStyle(
                              color:
                                  cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) =>
                      _buildMessage(_messages[i], cs),
                ),
        ),
        if (_loading)
          Container(
            padding: const EdgeInsets.only(
                left: 16, bottom: 4, right: 16),
            child: Row(children: [
              SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _modeColor())),
              const SizedBox(width: 8),
              Text("Working...",
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12)),
            ]),
          ),
        _buildInputBar(cs),
      ]),
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            top: BorderSide(
                color: const Color(0xFF30363D))),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12,
          8 + MediaQuery.of(context).padding.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              maxLines: 4,
              minLines: 1,
              enabled: !_loading,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: "Ask OpenCode...",
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _loading ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: _modeColor(),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12)),
            ),
            child: const Icon(Icons.send_rounded,
                size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(UIMessage msg, ColorScheme cs) {
    return switch (msg.type) {
      UIMessageType.system => _buildSystemBubble(msg, cs),
      UIMessageType.user => _buildUserBubble(msg, cs),
      UIMessageType.assistant =>
        _buildAssistantBubble(msg, cs),
      UIMessageType.toolCall ||
      UIMessageType.toolResult =>
        _buildToolCard(msg, cs),
      UIMessageType.toolPending =>
        _buildToolPending(msg, cs),
    };
  }

  Widget _buildSystemBubble(UIMessage msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(msg.content,
          style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildUserBubble(UIMessage msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(msg.content,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(
      UIMessage msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF30363D)),
              ),
              child: _renderContent(
                  msg.content, cs, false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(UIMessage msg, ColorScheme cs) {
    final isResult = msg.type == UIMessageType.toolResult;
    final icon = _toolIcon(msg.toolName ?? "");
    final color = _toolColor(msg.toolName ?? "");

    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 8,
          bottom: isResult ? 12 : 2),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tool header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7)),
              ),
              child: Row(children: [
                Text(icon,
                    style:
                        const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                    msg.toolName?.toUpperCase() ??
                        "TOOL",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5)),
                if (msg.toolArgs != null &&
                    msg.toolArgs!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        _truncate(
                            msg.toolArgs!, 50),
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                cs.onSurfaceVariant,
                            fontFamily: "monospace"),
                        overflow:
                            TextOverflow.ellipsis),
                  ),
                ],
              ]),
            ),
            // Tool result
            if (isResult)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontFamily: "monospace",
                    height: 1.4,
                  ),
                  maxLines: 15,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolPending(UIMessage msg, ColorScheme cs) {
    final color = _toolColor(msg.toolName ?? "");
    return Padding(
      padding: const EdgeInsets.only(
          left: 24, right: 8, bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withAlpha(80)),
        ),
        child: Row(children: [
          SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color)),
          const SizedBox(width: 8),
          Text(
              msg.toolName?.toUpperCase() ?? "TOOL",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
          if (msg.toolArgs != null) ...[
            const SizedBox(width: 6),
            Text(_truncate(msg.toolArgs!, 40),
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontFamily: "monospace")),
          ],
        ]),
      ),
    );
  }

  Widget _renderContent(
      String text, ColorScheme cs, bool isUser) {
    final textColor =
        isUser ? Colors.white : cs.onSurface;
    if (text.contains("```")) {
      final parts = <Widget>[];
      final regex = RegExp(r'```(\w*)\n([\s\S]*?)```',
          multiLine: true);
      int lastEnd = 0;
      for (final match in regex.allMatches(text)) {
        if (match.start > lastEnd) {
          parts.add(
              _textSpan(text.substring(lastEnd, match.start), textColor));
        }
        final lang = match.group(1) ?? "";
        final code = match.group(2) ?? "";
        parts.add(_codeBlock(lang, code, cs));
        lastEnd = match.end;
      }
      if (lastEnd < text.length) {
        parts.add(
            _textSpan(text.substring(lastEnd), textColor));
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: parts);
    }
    return _textSpan(text, textColor);
  }

  Widget _textSpan(String text, Color color) {
    return SelectableText(text,
        style: TextStyle(
            color: color,
            fontSize: 14,
            height: 1.55));
  }

  Widget _codeBlock(
      String lang, String code, ColorScheme cs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lang.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF30363D).withAlpha(60),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7)),
              ),
              child: Row(children: [
                Text(lang,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    // Could copy to clipboard
                  },
                  child: const Icon(Icons.copy,
                      size: 14,
                      color: Color(0xFF8B949E)),
                ),
              ]),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(code,
                style: const TextStyle(
                  fontFamily: "monospace",
                  fontSize: 12,
                  color: Color(0xFFE6EDF3),
                  height: 1.45,
                )),
          ),
        ],
      ),
    );
  }

  String _toolIcon(String name) => switch (name) {
        "read_file" => "📖",
        "write_file" => "✏️",
        "edit_file" => "📝",
        "delete_file" => "🗑",
        "list_files" => "📂",
        "search_code" => "🔍",
        "glob_files" => "🌐",
        "run_command" => "⚡",
        "git_sync" => "⬆",
        "git_status" => "📊",
        "web_search" => "🌍",
        "web_fetch" => "📄",
        "impact_analysis" => "🔗",
        "create_tasks" => "📋",
        "ask_user" => "❓",
        _ => "🔧",
      };

  Color _toolColor(String name) => switch (name) {
        "read_file" => const Color(0xFF58A6FF),
        "write_file" || "edit_file" =>
          const Color(0xFF3FB950),
        "delete_file" => const Color(0xFFF85149),
        "list_files" || "glob_files" =>
          const Color(0xFFA371F7),
        "search_code" => const Color(0xFFD2991D),
        "run_command" => const Color(0xFFF78166),
        "git_sync" || "git_status" =>
          const Color(0xFFF85149),
        "web_search" || "web_fetch" =>
          const Color(0xFF00BCD4),
        "create_tasks" => const Color(0xFF3FB950),
        "ask_user" => const Color(0xFFA371F7),
        _ => const Color(0xFF8B949E),
      };

  String _truncate(String text, int len) {
    if (text.length <= len) return text;
    return "${text.substring(0, len)}...";
  }
}

enum UIMessageType {
  system,
  user,
  assistant,
  toolCall,
  toolResult,
  toolPending,
}

class UIMessage {
  final int id;
  final UIMessageType type;
  String content;
  final String? toolName;
  final String? toolArgs;
  bool isStreaming;
  UIMessage({
    required this.id,
    required this.type,
    this.content = "",
    this.toolName,
    this.toolArgs,
    this.isStreaming = false,
  });
}
