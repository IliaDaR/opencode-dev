import "dart:convert";
import "package:http/http.dart" as http;

/// MCP (Model Context Protocol) client in pure Dart
/// Communicates with MCP servers via JSON-RPC over HTTP
/// Works with any MCP-compatible server — no Node.js/npx needed
class McpClient {
  final String serverUrl;
  final Map<String, String>? headers;
  int _requestId = 0;

  McpClient({required this.serverUrl, this.headers});

  Future<Map<String, dynamic>> _rpc(
      String method, Map<String, dynamic>? params) async {
    final id = ++_requestId;
    final body = jsonEncode({
      "jsonrpc": "2.0",
      "id": id,
      "method": method,
      if (params != null) "params": params,
    });

    final uri = Uri.parse(serverUrl);
    final response = await http.post(uri,
        headers: {
          "Content-Type": "application/json",
          ...?headers,
        },
        body: body);

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result["error"] != null) {
        throw Exception("MCP: ${result["error"]["message"]}");
      }
      return result["result"] ?? {};
    }
    throw Exception("MCP HTTP ${response.statusCode}");
  }

  /// Initialize connection to MCP server
  Future<Map<String, dynamic>> initialize() async {
    return await _rpc("initialize", {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "OpenCode-Mobile",
        "version": "1.0.0"
      },
    });
  }

  /// List available tools from the MCP server
  Future<List<Map<String, dynamic>>> listTools() async {
    final result = await _rpc("tools/list", null);
    final tools = result["tools"] as List? ?? [];
    return tools.cast<Map<String, dynamic>>();
  }

  /// Call a tool on the MCP server
  Future<Map<String, dynamic>> callTool(
      String name, Map<String, dynamic> arguments) async {
    return await _rpc("tools/call", {
      "name": name,
      "arguments": arguments,
    });
  }

  /// Quickly connect to a well-known MCP server and call a tool
  static Future<String> quickCall({
    required String url,
    required String tool,
    required Map<String, dynamic> args,
    Map<String, String>? headers,
  }) async {
    try {
      final client = McpClient(serverUrl: url, headers: headers);
      await client.initialize();
      final result = await client.callTool(tool, args);
      return const JsonEncoder.withIndent("  ").convert(result);
    } catch (e) {
      return "MCP call failed: $e";
    }
  }
}
