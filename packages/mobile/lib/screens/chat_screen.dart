import "dart:async";
import "dart:io";
import "package:flutter/material.dart";
import "../services/agent_service.dart";
import "../services/git_service.dart";
import "../services/storage_service.dart";

class ChatScreen extends StatefulWidget {
  final String projectName;
  final GitService gitService;

  const ChatScreen({
    super.key,
    required this.projectName,
    required this.gitService,
  });

  @override
  State<ChatScreen> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends State<ChatScreen> {
  late final AgentService _agent;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  AgentMode _mode = AgentMode.auto;
  String _gitStatus = "";
  List<String> _projectFiles = [];

  @override
  void initState() {
    super.initState();
    _agent = AgentService(projectName: widget.projectName);
    _agent.setGitService(widget.gitService);
    _init();
  }

  Future<void> _init() async {
    _addMessage("system", "Scanning project...");
    await _agent.scanProject();
    _agent.reset();

    if (_agent.projectContext != null) {
      final ctx = _agent.projectContext!;
      _projectFiles =
          ctx.files.where((f) => !f.startsWith(".")).toList();
      _addMessage("system",
          "Project **${widget.projectName}** loaded — ${ctx.files.length} files");
    }

    try {
      final status = await widget.gitService.getStatus();
      _gitStatus = status;
      if (status != "No changes" && status != "Not a git repository") {
        _addMessage("system", "Git: uncommitted changes detected");
      }
    } catch (_) {}

    _addMessage("assistant",
        "Ready. What are we working on?\n\n"
        "Modes: auto /brainstorm /architect /code /debug /refactor\n"
        "Type /<mode> to switch, or I'll detect automatically.");
  }

  void _addMessage(String role, String content) {
    setState(() {
      _messages.add(_ChatMessage(role: role, content: content));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });
  }

  void _setMode(AgentMode mode) {
    setState(() {
      _mode = mode;
    });
    _agent.setMode(mode);
    _addMessage("system", "Mode: ${mode.name.toUpperCase()}");
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
        final files = await StorageService.listDir(
            widget.projectName);
        final listing = files
            .map((e) {
              final name = e.uri.pathSegments.last;
              return e is Directory ? "[DIR]  $name/" : "       $name";
            })
            .join("\n");
        _addMessage("system", listing);
        return;
      }
      if (cmd == "/git" || cmd == "/status") {
        final status = await widget.gitService.getStatus();
        _gitStatus = status;
        _addMessage("system", status);
        return;
      }
      if (cmd == "/help") {
        _addMessage("system",
            "Commands: /auto /brainstorm /architect /code /debug /refactor\n"
            "/files — list project files\n"
            "/git — show git status\n"
            "/help — this message\n\n"
            "Just type your task — I'll auto-detect the mode.");
        return;
      }
    }

    _addMessage("user", text);
    setState(() {
      _loading = true;
    });

    String assistantContent = "";

    try {
      final stream = _agent.sendMessage(text);
      await for (final chunk in stream) {
        assistantContent += chunk;

        final last =
            _messages.isNotEmpty ? _messages.last : null;
        if (last != null &&
            last.role == "assistant" &&
            last.isStreaming) {
          setState(() {
            last.content = assistantContent;
          });
        } else {
          _addMessage("assistant", assistantContent);
          _messages.last.isStreaming = true;
        }
      }

      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        setState(() {
          _messages.last.isStreaming = false;
        });
      }

      final gs = await widget.gitService.getStatus();
      if (gs != _gitStatus) {
        _gitStatus = gs;
      }
    } catch (e) {
      _addMessage("error", "Error: $e");
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _modeColor() {
    return switch (_mode) {
      AgentMode.brainstorm => const Color(0xFFA371F7),
      AgentMode.architect => const Color(0xFF8E44AD),
      AgentMode.code => const Color(0xFF3FB950),
      AgentMode.debug => const Color(0xFFD2991D),
      AgentMode.refactor => const Color(0xFF58A6FF),
      AgentMode.auto => const Color(0xFF8B949E),
    };
  }

  String _modeLabel() {
    return switch (_mode) {
      AgentMode.brainstorm => "BRAINSTORM",
      AgentMode.architect => "ARCHITECT",
      AgentMode.code => "CODE",
      AgentMode.debug => "DEBUG",
      AgentMode.refactor => "REFACTOR",
      AgentMode.auto => "AUTO",
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.projectName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
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
          ],
        ),
        actions: [
          if (_gitStatus.isNotEmpty &&
              _gitStatus != "No changes")
            IconButton(
              icon: const Icon(Icons.call_split, size: 20),
              tooltip: _gitStatus,
              onPressed: () {
                _addMessage("system", _gitStatus);
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune, size: 20),
            onSelected: (v) {
              switch (v) {
                case "brainstorm":
                  _setMode(AgentMode.brainstorm);
                case "architect":
                  _setMode(AgentMode.architect);
                case "code":
                  _setMode(AgentMode.code);
                case "debug":
                  _setMode(AgentMode.debug);
                case "refactor":
                  _setMode(AgentMode.refactor);
                case "auto":
                  _setMode(AgentMode.auto);
                case "git_push":
                  _gitPush();
                case "git_pull":
                  _gitPull();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: "auto", child: Text("Auto detect")),
              const PopupMenuItem(
                  value: "brainstorm",
                  child: Text("Brainstorm ideas")),
              const PopupMenuItem(
                  value: "architect",
                  child: Text("Plan architecture")),
              const PopupMenuItem(
                  value: "code", child: Text("Write code")),
              const PopupMenuItem(
                  value: "debug", child: Text("Debug")),
              const PopupMenuItem(
                  value: "refactor", child: Text("Refactor")),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: "git_pull",
                  child: Text("Git pull")),
              const PopupMenuItem(
                  value: "git_push",
                  child: Text("Git push")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, cs);
              },
            ),
          ),

          if (_loading)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _modeColor())),
                  const SizedBox(width: 8),
                  Text(
                      "${_modeLabel()} mode...",
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12)),
                ],
              ),
            ),

          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                  top: BorderSide(
                      color: const Color(0xFF30363D))),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
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
                      hintText: "Message OpenCode...",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: _modeColor(),
                    minimumSize: const Size(48, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.send_rounded,
                      size: 20, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _gitPush() async {
    final r = await widget.gitService
        .commitAndPush("feat(mobile): update from OpenCode Mobile");
    _addMessage("system", r);
    _gitStatus = await widget.gitService.getStatus();
  }

  Future<void> _gitPull() async {
    final r = await widget.gitService.pull();
    _addMessage("system", r);
  }

  Widget _buildMessageBubble(_ChatMessage msg, ColorScheme cs) {
    if (msg.role == "system") {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          msg.content,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (msg.role == "error") {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2D1215),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.error),
          ),
          child: Text(msg.content,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.error,
                  fontFamily: "monospace")),
        ),
      );
    }

    final bool isUser = msg.role == "user";
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: 4, right: 4, bottom: 2),
            child: Text(
              isUser ? "You" : "OpenCode",
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.88),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? cs.primary : cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFF30363D)),
            ),
            child: _renderContent(msg.content, cs, isUser),
          ),
        ],
      ),
    );
  }

  Widget _renderContent(
      String text, ColorScheme cs, bool isUser) {
    final Color textColor =
        isUser ? Colors.white : cs.onSurface;

    if (text.contains("```")) {
      final parts = <Widget>[];
      final regex = RegExp(r'```(\w*)\n([\s\S]*?)```',
          multiLine: true);
      int lastEnd = 0;

      for (final match in regex.allMatches(text)) {
        if (match.start > lastEnd) {
          parts.add(Text(
              text.substring(lastEnd, match.start),
              style: TextStyle(
                  color: textColor, fontSize: 14, height: 1.5)));
        }

        final lang = match.group(1) ?? "";
        final code = match.group(2) ?? "";

        parts.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lang.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(lang,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant)),
                ),
              SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: "monospace",
                  fontSize: 12,
                  color: Color(0xFFE6EDF3),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ));

        lastEnd = match.end;
      }

      if (lastEnd < text.length) {
        parts.add(Text(text.substring(lastEnd),
            style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.5)));
      }

      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: parts);
    }

    return SelectableText(
      text,
      style: TextStyle(
          color: textColor, fontSize: 14, height: 1.5),
    );
  }
}

class _ChatMessage {
  final String role;
  String content;
  bool isStreaming;

  _ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });
}
