import "dart:convert";
import "package:http/http.dart" as http;

/// Browser-like web automation — replaces Playwright MCP
class BrowserService {
  /// Open a page and extract structured content
  static Future<String> openPage(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "User-Agent":
            "Mozilla/5.0 (Linux; Android) OpenCode-Mobile/1.0",
        "Accept": "text/html,application/xhtml+xml",
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return "HTTP ${response.statusCode}";
      }

      return _extractPage(url, response.body);
    } catch (e) {
      return "Failed to load page: $e";
    }
  }

  static String _extractPage(String url, String html) {
    final buffer = StringBuffer();
    buffer.writeln("URL: $url");
    buffer.writeln();

    // Extract title
    final titleMatch =
        RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
            .firstMatch(html);
    if (titleMatch != null) {
      buffer.writeln("Title: ${_decode(titleMatch.group(1)!)}");
    }

    // Extract meta description
    final descMatch = RegExp(
            "<meta[^>]*name=[\"']description[\"'][^>]*content=[\"']([^\"']+)[\"']",
            caseSensitive: false)
        .firstMatch(html);
    if (descMatch != null) {
      buffer.writeln("Description: ${_decode(descMatch.group(1)!)}");
    }

    // Extract links
    buffer.writeln("\n## Links");
    final linkRegex = RegExp(
        "<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
        caseSensitive: false);
    final links = <String>{};
    for (final match in linkRegex.allMatches(html)) {
      final href = match.group(1) ?? "";
      final text = _stripTags(_decode(match.group(2) ?? ""));
      if (text.trim().isNotEmpty &&
          !href.startsWith("#") &&
          !href.startsWith("javascript:")) {
        links.add("- $text\n  $href");
      }
      if (links.length >= 20) break;
    }
    buffer.writeln(links.join("\n"));

    // Extract headings
    buffer.writeln("\n## Structure");
    final headingRegex = RegExp(
        r'<h([1-6])[^>]*>(.*?)</h\1>',
        caseSensitive: false);
    for (final match in headingRegex.allMatches(html).take(15)) {
      final level = match.group(1) ?? "";
      final text =
          _stripTags(_decode(match.group(2) ?? ""));
      buffer.writeln("${"#" * int.parse(level)} $text");
    }

    // Extract text content
    buffer.writeln("\n## Content Preview");
    var text = html
        .replaceAll(
            RegExp(r'<(script|style|nav|footer|header)[^>]*>.*?</\1>',
                dotAll: true, caseSensitive: false),
            "")
        .replaceAll(RegExp(r'<[^>]+>'), " ")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();
    if (text.length > 2000) {
      text = text.substring(0, 2000);
    }
    buffer.writeln(text);

    return buffer.toString();
  }

  /// Extract specific data using CSS selector-like patterns
  static Future<String> extractData(
      String url, String pattern) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "User-Agent":
            "Mozilla/5.0 (Linux; Android) OpenCode-Mobile/1.0",
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return "HTTP ${response.statusCode}";
      }

      final html = response.body;
      final regex = RegExp(pattern, caseSensitive: false);
      final matches = regex.allMatches(html).take(20).toList();

      if (matches.isEmpty) {
        return "No matches for pattern: $pattern";
      }

      return matches.map((m) {
            if (m.groupCount >= 1) {
              return _stripTags(_decode(m.group(1) ?? ""));
            }
            return _stripTags(_decode(m.group(0) ?? ""));
          }).join("\n---\n");
    } catch (e) {
      return "Extract failed: $e";
    }
  }

  /// Follow a link on a page (simulate click)
  static Future<String> followLink(
      String url, String linkText) async {
    final content = await openPage(url);
    // Find matching link
    final response = await http.get(Uri.parse(url), headers: {
      "User-Agent":
          "Mozilla/5.0 (Linux; Android) OpenCode-Mobile/1.0",
    }).timeout(const Duration(seconds: 10));

    final linkRegex = RegExp(
        '<a[^>]*href=["\']([^"\']+)["\'][^>]*>.*?${RegExp.escape(linkText)}.*?</a>',
        caseSensitive: false);
    final match = linkRegex.firstMatch(response.body);

    if (match == null) {
      return "Link '$linkText' not found on $url\n\nPage content:\n$content";
    }

    var href = match.group(1) ?? "";
    if (!href.startsWith("http")) {
      final baseUri = Uri.parse(url);
      href = baseUri.resolve(href).toString();
    }

    return await openPage(href);
  }

  static String _decode(String html) {
    return html
        .replaceAll("&amp;", "&")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", '"')
        .replaceAll("&#39;", "'")
        .replaceAll("&nbsp;", " ")
        .replaceAll("&#x2F;", "/");
  }

  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), "")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();
  }
}
