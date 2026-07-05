import "dart:convert";
import "package:http/http.dart" as http;
import "settings_service.dart";

/// Full GitHub REST API integration — replaces MCP GitHub server
class GitHubService {
  static const _apiBase = "https://api.github.com";

  static Map<String, String> get _headers => {
        "Authorization": "Bearer ${SettingsService.githubToken}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
      };

  static Future<dynamic> _get(String endpoint,
      {Map<String, String>? params}) async {
    var uri = Uri.parse("$_apiBase$endpoint");
    if (params != null) {
      uri = uri.replace(queryParameters: params);
    }
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception("GitHub API ${res.statusCode}: ${res.body}");
  }

  static Future<dynamic> _post(
      String endpoint, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse("$_apiBase$endpoint"),
        headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception("GitHub API ${res.statusCode}: ${res.body}");
  }

  static Future<dynamic> _patch(
      String endpoint, Map<String, dynamic> body) async {
    final res = await http.patch(Uri.parse("$_apiBase$endpoint"),
        headers: _headers, body: jsonEncode(body));
    return jsonDecode(res.body);
  }

  /// List issues for a repo
  static Future<String> listIssues(
      String owner, String repo,
      {String state = "open",
      String? label,
      String? assignee,
      int perPage = 10}) async {
    try {
      final params = <String, String>{
        "state": state,
        "per_page": "$perPage",
        "sort": "updated",
        "direction": "desc",
      };
      if (label != null) params["labels"] = label;
      if (assignee != null) params["assignee"] = assignee;

      final issues = await _get("/repos/$owner/$repo/issues",
          params: params) as List;
      if (issues.isEmpty) return "No issues found";

      return issues
          .map((i) =>
              "#${i["number"] ?? "?"} [${i["state"] ?? "?"}] ${i["title"] ?? ""}\n  by ${i["user"]?["login"] ?? "unknown"} • ${i["comments"] ?? 0} comments\n  ${i["html_url"] ?? ""}")
          .join("\n\n");
    } catch (e) {
      return "GitHub API error: $e";
    }
  }

  /// Get single issue
  static Future<String> getIssue(
      String owner, String repo, int number) async {
    try {
      final issue =
          await _get("/repos/$owner/$repo/issues/$number");
      return "#${issue["number"]} ${issue["title"]}\n"
          "State: ${issue["state"]}\n"
          "Author: ${issue["user"]["login"]}\n"
          "Labels: ${(issue["labels"] as List).map((l) => l["name"]).join(", ")}\n"
          "Body:\n${issue["body"] ?? "(no description)"}\n"
          "URL: ${issue["html_url"]}";
    } catch (e) {
      return "GitHub API error: $e";
    }
  }

  /// Create an issue
  static Future<String> createIssue(
      String owner, String repo, String title, String body,
      {List<String>? labels}) async {
    try {
      final issue = await _post("/repos/$owner/$repo/issues", {
        "title": title,
        "body": body,
        if (labels != null) "labels": labels,
      });
      return "Created issue #${issue["number"]}: ${issue["html_url"]}";
    } catch (e) {
      return "Create issue failed: $e";
    }
  }

  /// List pull requests
  static Future<String> listPRs(
      String owner, String repo,
      {String state = "open", int perPage = 10}) async {
    try {
      final prs = await _get("/repos/$owner/$repo/pulls",
          params: {
            "state": state,
            "per_page": "$perPage",
            "sort": "updated",
            "direction": "desc",
          }) as List;
      if (prs.isEmpty) return "No PRs found";

      return prs
          .map((p) =>
              "#${p["number"] ?? "?"} ${p["title"] ?? ""}\n  by ${p["user"]?["login"] ?? "unknown"} • ${p["state"] ?? "?"}\n  ${p["html_url"] ?? ""}")
          .join("\n\n");
    } catch (e) {
      return "GitHub API error: $e";
    }
  }

  /// Get PR details with diff
  static Future<String> getPR(
      String owner, String repo, int number) async {
    try {
      final pr =
          await _get("/repos/$owner/$repo/pulls/$number");
      final files = await _get(
          "/repos/$owner/$repo/pulls/$number/files") as List;
      final fileList = files
          .take(10)
          .map((f) =>
              "${f["status"]}: ${f["filename"]} (+${f["additions"]} -${f["deletions"]})")
          .join("\n");
      return "#${pr["number"]} ${pr["title"]}\n"
          "State: ${pr["state"]} • Merged: ${pr["merged"]}\n"
          "Author: ${pr["user"]["login"]}\n"
          "Body: ${pr["body"] ?? ""}\n\n"
          "Files changed:\n$fileList\n"
          "URL: ${pr["html_url"]}";
    } catch (e) {
      return "GitHub API error: $e";
    }
  }

  /// Review a PR (approve, comment, request changes)
  static Future<String> reviewPR(
      String owner, String repo, int number, String event,
      [String? body]) async {
    try {
      final result =
          await _post("/repos/$owner/$repo/pulls/$number/reviews", {
        "event": event, // APPROVE, COMMENT, REQUEST_CHANGES
        if (body != null) "body": body,
      });
      return "Review submitted: ${result["state"]}";
    } catch (e) {
      return "Review failed: $e";
    }
  }

  /// Search code on GitHub
  static Future<String> searchCode(
      String query, {int perPage = 10}) async {
    try {
      final result = await _get("/search/code",
          params: {
            "q": query,
            "per_page": "$perPage",
          });
      final items = result["items"] as List? ?? [];
      if (items.isEmpty) return "No code results for: $query";

      return items
          .map((i) =>
              "${i["repository"]["full_name"]}/${i["path"]}\n  ${i["html_url"]}")
          .join("\n");
    } catch (e) {
      return "Search failed: $e";
    }
  }

  /// Get repository info
  static Future<String> getRepo(String owner, String repo) async {
    try {
      final r = await _get("/repos/$owner/$repo");
      return "${r["full_name"]}\n"
          "${r["description"] ?? ""}\n"
          "⭐ ${r["stargazers_count"]} • 🍴 ${r["forks_count"]}\n"
          "Issues: ${r["open_issues_count"]} • Language: ${r["language"]}\n"
          "URL: ${r["html_url"]}";
    } catch (e) {
      return "GitHub API error: $e";
    }
  }

  /// Get file content from repo
  static Future<String> getFileContent(
      String owner, String repo, String path,
      {String ref = "main"}) async {
    try {
      final file =
          await _get("/repos/$owner/$repo/contents/$path",
              params: {"ref": ref});
      if (file["content"] != null) {
        final content = utf8.decode(
            base64.decode(file["content"].toString().replaceAll("\n", "")));
        return content;
      }
      return "(binary or empty file)";
    } catch (e) {
      return "Cannot read file: $e";
    }
  }

  /// List repository branches
  static Future<String> listBranches(
      String owner, String repo) async {
    try {
      final branches =
          await _get("/repos/$owner/$repo/branches") as List;
      return branches
          .map((b) => "${b["name"]} (${b["commit"]["sha"].toString().substring(0, 7)})")
          .join("\n");
    } catch (e) {
      return "Error: $e";
    }
  }

  /// Create a Pull Request
  static Future<String> createPR(
      String owner, String repo, String title, String body,
      {String head = "master", String base = "main"}) async {
    try {
      final pr = await _post("/repos/$owner/$repo/pulls", {
        "title": title,
        "body": body,
        "head": head,
        "base": base,
      });
      return "Created PR #${pr["number"]}: ${pr["html_url"]}";
    } catch (e) {
      return "PR creation failed: $e";
    }
  }

  /// List releases
  static Future<String> listReleases(
      String owner, String repo) async {
    try {
      final releases =
          await _get("/repos/$owner/$repo/releases") as List;
      if (releases.isEmpty) return "No releases";
      return releases
          .take(5)
          .map((r) =>
              "${r["tag_name"]} • ${r["name"] ?? ""}\n  ${r["published_at"]}\n  ${r["html_url"]}")
          .join("\n\n");
    } catch (e) {
      return "Error: $e";
    }
  }
}
