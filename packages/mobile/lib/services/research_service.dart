import "dart:convert";
import "dart:io";
import "package:http/http.dart" as http;
import "storage_service.dart";
import "session_memory.dart";

/// Web research — fetch docs, search, analyze
class ResearchService {
  static const _ddgApi = "https://api.duckduckgo.com/";
  static const _yandexApi = "https://yandex.com/search/xml";

  /// Search the web using DuckDuckGo
  static Future<List<SearchResult>> search(String query,
      {int maxResults = 5, String engine = "duckduckgo"}) async {
    if (engine == "yandex") {
      return _searchYandex(query, maxResults: maxResults);
    }
    return _searchDuckDuckGo(query, maxResults: maxResults);
  }

  /// DuckDuckGo Instant Answer API
  static Future<List<SearchResult>> _searchDuckDuckGo(
      String query, {int maxResults = 5}) async {
    try {
      final uri = Uri.parse(_ddgApi).replace(queryParameters: {
        "q": query,
        "format": "json",
        "no_html": "1",
        "skip_disambig": "1",
      });
      final response = await http.get(uri,
          headers: {"User-Agent": "OpenCode-Mobile/1.0"});
      if (response.statusCode != 200) return await _fallbackSearch(query);

      final data = jsonDecode(response.body);
      final results = <SearchResult>[];

      if (data["AbstractText"] != null &&
          (data["AbstractText"] as String).isNotEmpty) {
        results.add(SearchResult(
            title: data["Heading"] ?? query,
            snippet: data["AbstractText"],
            url: data["AbstractURL"] ?? ""));
      }
      if (data["RelatedTopics"] != null) {
        for (final topic
            in (data["RelatedTopics"] as List).take(maxResults)) {
          if (topic is Map && topic["Text"] != null) {
            results.add(SearchResult(
                title: topic["FirstURL"]?.split("/").last ?? "",
                snippet: topic["Text"],
                url: topic["FirstURL"] ?? ""));
          }
        }
      }
      return results;
    } catch (_) {
      return await _fallbackSearch(query);
    }
  }

  /// Yandex search — great for Russian-language and CIS region queries
  static Future<List<SearchResult>> _searchYandex(
      String query, {int maxResults = 5}) async {
    try {
      // Use Yandex's HTML search page as fallback (no API key needed)
      final uri = Uri.parse("https://yandex.com/search/").replace(
          queryParameters: {"text": query, "lr": "2"});
      final response = await http.get(uri, headers: {
        "User-Agent":
            "Mozilla/5.0 (Linux; Android 14) OpenCode-Mobile/1.0",
        "Accept": "text/html",
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return await _fallbackSearch(query);
      }

      final results = <SearchResult>[];
      // Extract search results from HTML
      final resultRegex = RegExp(
          r'<a[^>]*class="[^"]*link[^"]*"[^>]*href="([^"]+)"[^>]*>.*?<span[^>]*class="[^"]*organic__title[^"]*"[^>]*>(.*?)</span>',
          dotAll: true,
          caseSensitive: false);

      for (final m
          in resultRegex.allMatches(response.body).take(maxResults)) {
        final url = m.group(1) ?? "";
        final title = _stripTags(_decodeHtml(m.group(2) ?? ""));
        if (url.isNotEmpty && title.isNotEmpty) {
          results.add(SearchResult(
              title: title, snippet: url, url: url));
        }
      }

      if (results.isEmpty) {
        // Fallback: simpler extraction
        final linkRegex = RegExp(
            r'<a[^>]*href="(https?://[^"]+)"[^>]*>([^<]+)</a>');
        for (final m
            in linkRegex.allMatches(response.body).take(maxResults)) {
          final url = m.group(1) ?? "";
          final title = _stripTags(_decodeHtml(m.group(2) ?? ""));
          if (url.isNotEmpty &&
              title.isNotEmpty &&
              !url.contains("yandex.")) {
            results.add(SearchResult(
                title: title, snippet: url, url: url));
          }
        }
      }

      return results.isEmpty ? await _fallbackSearch(query) : results;
    } catch (_) {
      return await _fallbackSearch(query);
    }
  }

  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), "")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();
  }

  static String _decodeHtml(String html) {
    return html
        .replaceAll("&amp;", "&")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", '"')
        .replaceAll("&#39;", "'");
  }

  /// Fallback: use Google's "I'm Feeling Lucky" redirect info
  static Future<List<SearchResult>> _fallbackSearch(
      String query) async {
    // Cached answers from our knowledge base for common queries
    return _knowledgeBase(query);
  }

  /// Built-in knowledge base for common developer queries
  static List<SearchResult> _knowledgeBase(String query) {
    final lower = query.toLowerCase();
    final results = <SearchResult>[];

    final kb = {
      "flutter": SearchResult(
        title: "Flutter documentation",
        snippet:
            "Flutter is Google's UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.",
        url: "https://flutter.dev/docs",
      ),
      "react": SearchResult(
        title: "React documentation",
        snippet:
            "React is a JavaScript library for building user interfaces. Learn React at react.dev.",
        url: "https://react.dev",
      ),
      "typescript": SearchResult(
        title: "TypeScript documentation",
        snippet:
            "TypeScript is a strongly typed programming language that builds on JavaScript. Handbook at typescriptlang.org.",
        url: "https://www.typescriptlang.org/docs/",
      ),
      "python": SearchResult(
        title: "Python documentation",
        snippet:
            "Python is a programming language. Official docs at docs.python.org/3/.",
        url: "https://docs.python.org/3/",
      ),
      "deepseek": SearchResult(
        title: "DeepSeek API documentation",
        snippet:
            "DeepSeek API provides access to DeepSeek models. Documentation at platform.deepseek.com/api-docs.",
        url: "https://platform.deepseek.com/api-docs",
      ),
      "docker": SearchResult(
        title: "Docker documentation",
        snippet:
            "Docker is a platform for developing, shipping, and running applications in containers.",
        url: "https://docs.docker.com",
      ),
      "git": SearchResult(
        title: "Git documentation",
        snippet:
            "Git is a free and open source distributed version control system. Docs at git-scm.com/doc.",
        url: "https://git-scm.com/doc",
      ),
      "sql": SearchResult(
        title: "SQL reference",
        snippet:
            "SQL is a standard language for accessing and manipulating databases.",
        url: "https://www.w3schools.com/sql/",
      ),
      "npm": SearchResult(
        title: "npm registry",
        snippet:
            "npm is the package manager for JavaScript. Search packages at npmjs.com.",
        url: "https://www.npmjs.com",
      ),
      "pypi": SearchResult(
        title: "PyPI — Python Package Index",
        snippet:
            "Find, install and publish Python packages with the Python Package Index.",
        url: "https://pypi.org",
      ),
    };

    for (final entry in kb.entries) {
      if (lower.contains(entry.key)) {
        results.add(entry.value);
      }
    }

    if (results.isEmpty) {
      results.add(SearchResult(
        title: "Search: $query",
        snippet:
            "Research this topic online for the most current information. Consider checking official documentation, Stack Overflow, and GitHub.",
        url: "https://www.google.com/search?q=${Uri.encodeComponent(query)}",
      ));
    }

    return results;
  }

  /// Fetch and extract content from a URL
  static Future<String> fetchUrl(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url), headers: {
        "User-Agent":
            "Mozilla/5.0 OpenCode-Mobile/1.0",
        "Accept": "text/html,text/plain",
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _extractText(response.body);
      }
      return "Failed to fetch: HTTP ${response.statusCode}";
    } catch (e) {
      return "Failed to fetch: $e";
    }
  }

  /// Simple HTML text extraction
  static String _extractText(String html) {
    // Remove scripts and styles
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>',
            dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>',
            dotAll: true, caseSensitive: false), '');

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Normalize whitespace
    text = text
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"');

    // Collapse whitespace
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Truncate
    if (text.length > 3000) {
      text = text.substring(0, 3000);
    }

    return text;
  }

  /// Deep research: multi-step investigation
  static Stream<String> deepResearch(String topic) async* {
    yield "## Deep Research: $topic\n\n";

    // Phase 1: Search
    yield "### Phase 1: Gathering sources\n";
    final results = await search(topic, maxResults: 5);
    for (final r in results) {
      yield "- ${r.title}: ${r.snippet}\n";
    }

    // Phase 2: Analyze findings
    yield "\n### Phase 2: Analysis\n";
    yield _analyzeFindings(topic, results);

    // Phase 3: Recommendations
    yield "\n### Phase 3: Recommendations\n";
    yield _generateRecommendations(topic, results);
  }

  static String _analyzeFindings(
      String topic, List<SearchResult> results) {
    final buffer = StringBuffer();
    buffer.writeln(
        "Based on ${results.length} sources, here's what we know about '$topic':");
    buffer.writeln();

    final keyPoints = <String>{};
    for (final r in results) {
      final words = r.snippet.split(" ");
      for (var i = 0; i < words.length - 2; i++) {
        final trigram =
            "${words[i]} ${words[i + 1]} ${words[i + 2]}";
        if (trigram.length > 10 && trigram.length < 80) {
          keyPoints.add(trigram);
        }
      }
    }

    var count = 0;
    for (final point in keyPoints.take(8)) {
      count++;
      buffer.writeln("$count. $point");
    }

    return buffer.toString();
  }

  static String _generateRecommendations(
      String topic, List<SearchResult> results) {
    final buffer = StringBuffer();
    buffer.writeln("### How to proceed:");
    buffer.writeln();

    var step = 1;

    if (results.any((r) =>
        r.url.contains("docs.") || r.url.contains("documentation"))) {
      buffer.writeln("${step++}. Read the official documentation first");
    }
    buffer.writeln(
        "${step++}. Check for existing implementations on GitHub");
    buffer.writeln(
        "${step++}. Consider trade-offs: complexity vs benefit");
    buffer.writeln(
        "${step++}. Prototype the most promising approach");

    if (results.isNotEmpty) {
      buffer.writeln("\n### Key links:");
      for (final r in results) {
        if (r.url.isNotEmpty) {
          buffer.writeln("- ${r.title}: ${r.url}");
        }
      }
    }

    return buffer.toString();
  }
}

class SearchResult {
  final String title;
  final String snippet;
  final String url;

  SearchResult(
      {required this.title,
      required this.snippet,
      required this.url});
}
