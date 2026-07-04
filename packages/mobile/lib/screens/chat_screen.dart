import "dart:async";
import "package:flutter/material.dart";
import "../services/agent_service.dart";
import "../services/git_service.dart";

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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _agent = AgentService(projectName: widget.projectName);
    _agent.setGitService(widget.gitService);
    _init();
  }

  Future<void> _init() async {
    _addMessage("assistant",
        "Project **${widget.projectName}** ready.\nWhat should we work on?");

    try {
      final result = await widget.gitService.pull();
      if (result != "Already up to date") {
        _addMessage("system", result);
      }
    } catch (_) {}

    setState(() {
      _initialized = true;
    });
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

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) {
      return;
    }

    _inputCtrl.clear();
    _addMessage("user", text);
    setState(() {
      _loading = true;
    });

    String assistantContent = "";

    try {
      final stream = _agent.sendMessage(text);
      await for (final chunk in stream) {
        assistantContent += chunk;

        final last = _messages.isNotEmpty ? _messages.last : null;
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: "Pull",
            onPressed: () async {
              final r = await widget.gitService.pull();
              _addMessage("system", r);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: "Push",
            onPressed: () async {
              final r = await widget.gitService
                  .commitAndPush("Mobile sync");
              _addMessage("system", r);
            },
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
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                          strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text("Thinking...",
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
                12,
                8,
                12,
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
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    minimumSize: const Size(52, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ColorScheme cs) {
    if (msg.role == "system" || msg.role == "error") {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          msg.content,
          style: TextStyle(
            fontSize: 12,
            color: msg.role == "error"
                ? cs.error
                : cs.onSurfaceVariant,
            fontFamily: "monospace",
          ),
        ),
      );
    }

    final bool isUser = msg.role == "user";
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(left: 4, right: 4, bottom: 2),
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
                    MediaQuery.of(context).size.width * 0.85),
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
                  color: textColor, fontSize: 14)));
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
                color: textColor, fontSize: 14)));
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
