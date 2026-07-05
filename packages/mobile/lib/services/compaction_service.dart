import "dart:convert";
import "package:http/http.dart" as http;
import "settings_service.dart";

/// AI-powered context compaction using DeepSeek to summarize old messages
/// Replaces the simple text-truncation ContextManager
class CompactionService {
  static const _api = "https://api.deepseek.com/v1/chat/completions";

  /// Compress old messages into a summary using AI
  static Future<String> compress(List<Map<String, dynamic>> messages) async {
    if (messages.length < 10) return "";

    final toSummarize = messages.sublist(0, messages.length - 6);
    final conversation = toSummarize
        .map((m) => "${m["role"]}: ${_truncate(m["content"]?.toString() ?? "", 200)}")
        .join("\n");

    final body = jsonEncode({
      "model": "deepseek-chat",
      "messages": [
        {
          "role": "system",
          "content": "Summarize this conversation into 3-5 bullet points. Focus on: decisions made, files changed, key findings, unresolved questions. Be concise."
        },
        {
          "role": "user",
          "content": conversation,
        }
      ],
      "temperature": 0.1,
      "max_tokens": 500,
    });

    try {
      final res = await http.post(Uri.parse(_api), headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SettingsService.deepseekApiKey}",
      }, body: body).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final summary = json["choices"][0]["message"]["content"] ?? "";
        return "## Session Summary\n$summary";
      }
    } catch (_) {}

    return "";
  }

  static String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return "${text.substring(0, max)}...";
  }
}
