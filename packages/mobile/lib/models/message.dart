class ToolCall {
  final String id;
  final String name;
  final String arguments;

  ToolCall(
      {required this.id,
      required this.name,
      required this.arguments});

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "type": "function",
      "function": {"name": name, "arguments": arguments},
    };
  }
}

class Message {
  final String role;
  final String content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;

  Message({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      "role": role,
      "content": content,
    };
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map["tool_calls"] =
          toolCalls!.map((tc) => tc.toJson()).toList();
    }
    if (toolCallId != null) {
      map["tool_call_id"] = toolCallId;
    }
    return map;
  }
}
