import "dart:io";
import "storage_service.dart";

/// Deployment & infrastructure operations
class DeploymentService {
  /// Check if project is ready for deployment
  static Future<String> checkDeployReadiness(
      String project) async {
    final checks = <String>[];
    var pass = 0;
    var fail = 0;

    // Dockerfile
    try {
      await StorageService.readFile(
          project, "Dockerfile");
      checks.add("✅ Dockerfile present");
      pass++;
    } catch (_) {
      checks.add("❌ No Dockerfile");
      fail++;
    }

    // .gitignore
    try {
      final gi = await StorageService.readFile(
          project, ".gitignore");
      if (gi.contains("node_modules") ||
          gi.contains("__pycache__") ||
          gi.contains(".env")) {
        checks.add("✅ .gitignore covers build artifacts");
        pass++;
      } else {
        checks.add("⚠️ .gitignore may be incomplete");
      }
    } catch (_) {
      checks.add("❌ No .gitignore");
      fail++;
    }

    // Environment config
    try {
      await StorageService.readFile(
          project, ".env.example");
      checks.add("✅ .env.example present");
      pass++;
    } catch (_) {
      final hasEnv = await _fileExists(project, ".env");
      checks.add(hasEnv
          ? "⚠️ .env exists but no .env.example — add template"
          : "❌ No .env.example — add environment variable template");
      fail++;
    }

    // Package manager lockfile
    final hasLock = await _fileExists(project, "package-lock.json") ||
        await _fileExists(project, "pnpm-lock.yaml") ||
        await _fileExists(project, "yarn.lock") ||
        await _fileExists(project, "bun.lock") ||
        await _fileExists(project, "poetry.lock") ||
        await _fileExists(project, "requirements.txt");
    checks.add(hasLock
        ? "✅ Lockfile present (deterministic builds)"
        : "❌ No lockfile — builds not deterministic");
    hasLock ? pass++ : fail++;

    // README
    try {
      final readme =
          await StorageService.readFile(project, "README.md");
      if (readme.length > 100) {
        checks.add("✅ README with documentation");
        pass++;
      } else {
        checks.add("⚠️ README is too short");
      }
    } catch (_) {
      checks.add("❌ No README — add documentation");
      fail++;
    }

    // CI/CD
    final hasCI = await _dirExists(project, ".github/workflows") ||
        await _dirExists(project, ".gitlab-ci.yml");
    checks.add(hasCI
        ? "✅ CI/CD configured"
        : "ℹ️ No CI/CD — consider adding GitHub Actions");

    final buf = StringBuffer();
    buf.writeln("## Deployment Readiness: $project\n");
    buf.writeln("Passed: $pass | Failed: $fail\n");
    checks.forEach((c) => buf.writeln(c));
    buf.writeln("\nScore: ${(pass + fail) > 0 ? pass * 100 ~/ (pass + fail) : 0}%");

    return buf.toString();
  }

  /// Generate docker-compose for common stacks
  static String generateDockerCompose(
      String stack, Map<String, String> config) {
    switch (stack) {
      case "node-postgres":
        return _nodePostgresCompose(config);
      case "python-postgres":
        return _pythonPostgresCompose(config);
      case "node-mongo":
        return _nodeMongoCompose(config);
      default:
        return "Unknown stack: $stack. Try: node-postgres, python-postgres, node-mongo";
    }
  }

  static String _nodePostgresCompose(Map<String, String> c) {
    return '''
version: "3.8"
services:
  app:
    build: .
    ports: ["${c["port"] ?? "3000"}:${c["port"] ?? "3000"}"]
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/${c["db"] ?? "app"}
      NODE_ENV: development
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - .:/app
      - /app/node_modules
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ${c["db"] ?? "app"}
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
''';
  }

  static String _pythonPostgresCompose(Map<String, String> c) {
    return '''
version: "3.8"
services:
  app:
    build: .
    ports: ["${c["port"] ?? "8000"}:${c["port"] ?? "8000"}"]
    environment:
      DATABASE_URL: postgresql://postgres:postgres@db:5432/${c["db"] ?? "app"}
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - .:/app
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ${c["db"] ?? "app"}
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
''';
  }

  static String _nodeMongoCompose(Map<String, String> c) {
    return '''
version: "3.8"
services:
  app:
    build: .
    ports: ["${c["port"] ?? "3000"}:${c["port"] ?? "3000"}"]
    environment:
      MONGODB_URI: mongodb://db:27017/${c["db"] ?? "app"}
    depends_on:
      - db
    volumes:
      - .:/app
      - /app/node_modules

  db:
    image: mongo:7
    ports: ["27017:27017"]
    volumes:
      - mongodata:/data/db

volumes:
  mongodata:
''';
  }

  static Future<bool> _fileExists(
      String project, String path) async {
    try {
      await StorageService.readFile(project, path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _dirExists(
      String project, String path) async {
    try {
      final entries =
          await StorageService.listDir(project, path);
      return entries.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Generate CI/CD config
  static String generateCIConfig(String platform,
      {String? nodeVersion, String? pythonVersion}) {
    switch (platform) {
      case "github-node":
        return _githubNodeCI(nodeVersion ?? "20");
      case "github-python":
        return _githubPythonCI(pythonVersion ?? "3.12");
      case "github-flutter":
        return _githubFlutterCI();
      default:
        return "Platform: $platform. Try: github-node, github-python, github-flutter";
    }
  }

  static String _githubNodeCI(String nodeVersion) {
    return '''
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "$nodeVersion", cache: "npm" }
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test
''';
  }

  static String _githubPythonCI(String pythonVersion) {
    return '''
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "$pythonVersion" }
      - run: pip install -r requirements.txt
      - run: ruff check .
      - run: pytest
''';
  }

  static String _githubFlutterCI() {
    return '''
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: "3.24", channel: "stable" }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release
''';
  }
}
