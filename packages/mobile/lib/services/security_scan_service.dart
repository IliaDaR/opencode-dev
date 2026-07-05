import "dart:io";
import "storage_service.dart";

/// Full OWASP Top 10 security scan
class SecurityScanService {
  /// Scan entire project for security vulnerabilities
  static Future<String> scanProject(String project) async {
    final buf = StringBuffer();
    buf.writeln("## Security Scan: $project\n");
    buf.writeln("Checking OWASP Top 10 vulnerabilities...\n");

    var critical = 0;
    var warning = 0;
    var info = 0;

    await _scanDir(project, "", (file, content) {
      final issues = _checkFile(file, content);
      if (issues.isNotEmpty) {
        buf.writeln("### $file");
        for (final issue in issues) {
          buf.writeln(issue);
          if (issue.contains("🔴")) critical++;
          else if (issue.contains("⚠️")) warning++;
          else info++;
        }
        buf.writeln();
      }
    });

    buf.writeln("---");
    buf.writeln("🔴 Critical: $critical | ⚠️ Warnings: $warning | ℹ️ Info: $info");

    if (critical == 0 && warning == 0) {
      buf.writeln("\n✅ No significant security issues found.");
    }

    return buf.toString();
  }

  static List<String> _checkFile(String filePath, String content) {
    final issues = <String>[];

    // A1: Broken Access Control
    if (content.contains("admin") && !content.contains("auth") && !content.contains("permission")) {
      issues.add("⚠️ A1: Admin route without visible auth check");
    }

    // A2: Cryptographic Failures
    if (RegExp(r'MD5|SHA1|sha1', caseSensitive: false).hasMatch(content) &&
        !RegExp(r'"md5"|"sha1"|md5file', caseSensitive: false).hasMatch(content)) {
      issues.add("🔴 A2: Weak hash algorithm (MD5/SHA1). Use SHA-256 or bcrypt.");
    }

    // A3: Injection
    if (RegExp(r'execute\s*\(.*\+|exec\s*\(.*\+|eval\s*\(.*\+|system\s*\(.*\+').hasMatch(content)) {
      issues.add("🔴 A3: Potential command injection — string concatenation in exec/eval/system");
    }
    if (RegExp(r'raw.*query|raw.*execute|\.sql\(.*\+|\.query\(.*\+').hasMatch(content)) {
      issues.add("🔴 A3: Potential SQL injection — raw query with string concatenation");
    }

    // A4: Insecure Design
    if (RegExp(r'rate.?limit|throttle', caseSensitive: false).hasMatch(content) == false &&
        RegExp(r'\.get\(|\.post\(|app\.use\(|router\.', caseSensitive: false).hasMatch(content)) {
      issues.add("ℹ️ A4: API endpoint without visible rate limiting");
    }

    // A5: Security Misconfiguration
    if (RegExp("debug\\s*=\\s*True|DEBUG\\s*=\\s*true|NODE_ENV\\s*=\\s*[\"']development[\"']").hasMatch(content)) {
      issues.add("⚠️ A5: Debug mode enabled — should be off in production");
    }

    // A6: Vulnerable Components — check hardcoded versions
    if (RegExp("version\\s*=\\s*[\"']0\\.\\d+|version\\s*=\\s*[\"']\\d+\\.0\\.0[\"']").hasMatch(content)) {
      issues.add("ℹ️ A6: Very early version dependency — check for known CVEs");
    }

    // A7: Auth Failures
    if (RegExp("password\\s*=\\s*[\"'][^\"']+[\"']").hasMatch(content) &&
        !content.contains(".env") && !content.contains("example")) {
      issues.add("🔴 A7: Hardcoded password detected");
    }
    if (RegExp("api.?key\\s*=\\s*[\"'][^\"']+[\"']|secret\\s*=\\s*[\"'][^\"']+[\"']|token\\s*=\\s*[\"'][^\"']+[\"']").hasMatch(content) &&
        !filePath.contains(".env.example") && !content.contains("process.env") && !content.contains("import.meta.env")) {
      issues.add("🔴 A7: Hardcoded secret/key/token detected");
    }

    // A8: Software & Data Integrity
    if (RegExp(r'http://', caseSensitive: false).hasMatch(content) &&
        !content.contains("localhost") && !content.contains("127.0.0.1")) {
      issues.add("⚠️ A8: HTTP (non-HTTPS) URL in code");
    }

    // A10: SSRF
    if (RegExp("fetch\\s*\\(\\s*[a-zA-Z]|axios\\.get\\s*\\(\\s*[a-zA-Z]|requests\\.get\\s*\\(\\s*[a-zA-Z]|curl\\s+").hasMatch(content) &&
        RegExp(r'url|request\.params|req\.query|req\.body').hasMatch(content)) {
      issues.add("⚠️ A10: Potential SSRF — user input in HTTP request URL");
    }

    return issues;
  }

  static Future<void> _scanDir(
      String project, String path,
      void Function(String file, String content) onFile) async {
    final entries = await StorageService.listDir(project, path);
    for (final e in entries) {
      final name = e.uri.pathSegments.last;
      final full = path.isEmpty ? name : "$path/$name";

      if (e is Directory) {
        if (name.startsWith(".") || name == "node_modules" || name == "dist") continue;
        await _scanDir(project, full, onFile);
      } else {
        final ext = name.split(".").last;
        if (!["ts","tsx","js","jsx","py","rb","php","java","go","rs"].contains(ext)) continue;
        try {
          final content = await StorageService.readFile(project, full);
          onFile(full, content);
        } catch (_) {}
      }
    }
  }
}
