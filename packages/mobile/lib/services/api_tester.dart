import "dart:convert";
import "package:http/http.dart" as http;

/// API testing — test REST endpoints directly from chat
class ApiTester {
  /// Test a GET endpoint
  static Future<String> get(String url,
      {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: {
        "User-Agent": "OpenCode-Mobile/1.0",
        if (headers != null) ...headers,
      }).timeout(const Duration(seconds: 15));

      return _formatResponse(response);
    } catch (e) {
      return "GET $url failed: $e";
    }
  }

  /// Test a POST endpoint
  static Future<String> post(String url, String body,
      {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.post(uri, headers: {
        "Content-Type": "application/json",
        "User-Agent": "OpenCode-Mobile/1.0",
        if (headers != null) ...headers,
      }, body: body).timeout(const Duration(seconds: 15));

      return _formatResponse(response);
    } catch (e) {
      return "POST $url failed: $e";
    }
  }

  /// Test multiple endpoints from an API
  static Future<String> testEndpoints(
      String baseUrl, List<Map<String, String>> endpoints) async {
    final buf = StringBuffer();
    buf.writeln("## API Test: $baseUrl\n");

    for (final ep in endpoints) {
      final method = ep["method"] ?? "GET";
      final path = ep["path"] ?? "/";
      final url = "$baseUrl$path";

      buf.writeln("### $method $path");

      try {
        final response = method == "POST"
            ? await http.post(Uri.parse(url), headers: {
                "Content-Type": "application/json",
              }, body: ep["body"] ?? "{}")
            : await http.get(Uri.parse(url));

        buf.writeln("Status: ${response.statusCode}");
        if (response.statusCode < 400) {
          buf.writeln("✅ PASS");
        } else {
          buf.writeln("❌ FAIL");
        }

        if (response.body.isNotEmpty && response.body.length < 500) {
          buf.writeln("```json\n${_prettify(response.body)}\n```");
        }
      } catch (e) {
        buf.writeln("❌ Error: $e");
      }
      buf.writeln();
    }

    return buf.toString();
  }

  static String _formatResponse(http.Response response) {
    final buf = StringBuffer();
    buf.writeln("Status: ${response.statusCode}");
    buf.writeln(
        "Time: ${response.headers["x-response-time"] ?? "unknown"}");

    if (response.body.isNotEmpty && response.body.length < 2000) {
      final pretty = _prettify(response.body);
      buf.writeln("\n```json\n$pretty\n```");
    }
    return buf.toString();
  }

  static String _prettify(String raw) {
    try {
      final parsed = jsonDecode(raw);
      return const JsonEncoder.withIndent("  ").convert(parsed);
    } catch (_) {
      return raw;
    }
  }
}
