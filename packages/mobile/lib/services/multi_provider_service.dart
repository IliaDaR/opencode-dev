import "dart:async";
import "dart:convert";
import "package:http/http.dart" as http;
import "settings_service.dart";

/// Multi-provider support — Gemini (free tier!), OpenAI, Anthropic
/// Falls back through providers if one fails
class MultiProviderService {
  static const _deepseekApi = "https://api.deepseek.com/v1/chat/completions";
  static const _geminiApi = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
  static const _openaiApi = "https://api.openai.com/v1/chat/completions";
  static const _anthropicApi = "https://api.anthropic.com/v1/messages";

  static String? _geminiKey;
  static String? _openaiKey;
  static String? _anthropicKey;

  static void setGeminiKey(String key) => _geminiKey = key;
  static void setOpenAIKey(String key) => _openaiKey = key;
  static void setAnthropicKey(String key) => _anthropicKey = key;

  /// Try providers in order, return first successful response
  static Future<Map<String, dynamic>?> tryProviders(
      List<Map<String, dynamic>> messages,
      {List<Map<String, dynamic>>? tools,
      double temperature = 0.2,
      int maxTokens = 4096}) async {

    // 1. DeepSeek (primary)
    try {
      final r = await _callDeepSeek(messages, tools: tools, temp: temperature, maxTokens: maxTokens);
      if (r != null) return r;
    } catch (_) {}

    // 2. Gemini (free tier — 1500 req/day)
    if (_geminiKey != null) {
      try {
        final r = await _callGemini(messages, temp: temperature, maxTokens: maxTokens);
        if (r != null) return r;
      } catch (_) {}
    }

    // 3. OpenAI
    if (_openaiKey != null) {
      try {
        final r = await _callOpenAI(messages, tools: tools, temp: temperature, maxTokens: maxTokens);
        if (r != null) return r;
      } catch (_) {}
    }

    // 4. Anthropic
    if (_anthropicKey != null) {
      try {
        final r = await _callAnthropic(messages, tools: tools, temp: temperature, maxTokens: maxTokens);
        if (r != null) return r;
      } catch (_) {}
    }

    return null; // All providers failed
  }

  static Future<Map<String, dynamic>?> _callDeepSeek(
      List<Map<String, dynamic>> messages,
      {List<Map<String, dynamic>>? tools, double temp = 0.2, int maxTokens = 4096}) async {
    final body = jsonEncode({
      "model": "deepseek-chat",
      "messages": messages,
      if (tools != null) "tools": tools,
      "temperature": temp,
      "max_tokens": maxTokens,
    });
    final res = await http.post(Uri.parse(_deepseekApi), headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer ${SettingsService.deepseekApiKey}",
    }, body: body).timeout(const Duration(seconds: 90));
    if (res.statusCode == 200) return _normalizeDeepSeek(jsonDecode(res.body));
    return null;
  }

  static Future<Map<String, dynamic>?> _callGemini(
      List<Map<String, dynamic>> messages,
      {double temp = 0.2, int maxTokens = 4096}) async {
    // Convert messages to Gemini format
    final contents = <Map<String, dynamic>>[];
    for (final m in messages) {
      final role = m["role"] == "assistant" ? "model" : "user";
      if (role == "system") continue; // Gemini handles system prompt differently
      contents.add({
        "role": role,
        "parts": [{"text": m["content"] ?? ""}],
      });
    }

    // Extract system message if present
    final systemMsg = messages.where((m) => m["role"] == "system").map((m) => m["content"]).join("\n");

    final body = jsonEncode({
      "contents": contents,
      if (systemMsg.isNotEmpty) "systemInstruction": {"parts": [{"text": systemMsg}]},
      "generationConfig": {"temperature": temp, "maxOutputTokens": maxTokens},
    });

    final uri = "$_geminiApi?key=$_geminiKey";
    final res = await http.post(Uri.parse(uri), headers: {"Content-Type": "application/json"},
        body: body).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) return _normalizeGemini(jsonDecode(res.body));
    return null;
  }

  static Future<Map<String, dynamic>?> _callOpenAI(
      List<Map<String, dynamic>> messages,
      {List<Map<String, dynamic>>? tools, double temp = 0.2, int maxTokens = 4096}) async {
    final body = jsonEncode({
      "model": "gpt-4o-mini",
      "messages": messages,
      if (tools != null) "tools": tools,
      "temperature": temp,
      "max_tokens": maxTokens,
    });
    final res = await http.post(Uri.parse(_openaiApi), headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $_openaiKey",
    }, body: body).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<Map<String, dynamic>?> _callAnthropic(
      List<Map<String, dynamic>> messages,
      {List<Map<String, dynamic>>? tools, double temp = 0.2, int maxTokens = 4096}) async {
    final body = jsonEncode({
      "model": "claude-3-haiku-20240307",
      "max_tokens": maxTokens,
      "temperature": temp,
      "messages": messages.where((m) => m["role"] != "system").toList(),
      "system": messages.where((m) => m["role"] == "system").map((m) => m["content"]).join("\n"),
      if (tools != null) "tools": _toAnthropicTools(tools),
    });
    final res = await http.post(Uri.parse(_anthropicApi), headers: {
      "Content-Type": "application/json",
      "x-api-key": _anthropicKey!,
      "anthropic-version": "2023-06-01",
    }, body: body).timeout(const Duration(seconds: 60));
    if (res.statusCode == 200) return _normalizeAnthropic(jsonDecode(res.body));
    return null;
  }

  static List<Map<String, dynamic>> _toAnthropicTools(List<Map<String, dynamic>> openAITools) {
    return openAITools.map((t) => {
      "name": t["function"]["name"],
      "description": t["function"]["description"],
      "input_schema": t["function"]["parameters"],
    }).toList();
  }

  static Map<String, dynamic> _normalizeDeepSeek(Map<String, dynamic> raw) {
    final choice = raw["choices"][0];
    return {"message": choice["message"], "finish_reason": choice["finish_reason"]};
  }

  static Map<String, dynamic> _normalizeGemini(Map<String, dynamic> raw) {
    final candidate = raw["candidates"]?[0];
    final content = candidate?["content"];
    final parts = content?["parts"] as List?;
    final text = parts?.map((p) => p["text"] ?? "").join("") ?? "";
    return {"message": {"role": "assistant", "content": text}, "finish_reason": "stop"};
  }

  static Map<String, dynamic> _normalizeAnthropic(Map<String, dynamic> raw) {
    final content = raw["content"] as List?;
    final text = content?.map((c) => c["text"] ?? "").join("") ?? "";
    return {"message": {"role": "assistant", "content": text}, "finish_reason": "stop"};
  }
}
