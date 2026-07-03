import "dart:io";
import "storage_service.dart";
import "settings_service.dart";

class GitService {
  final String projectName;
  final String repoUrl;
  final String token;

  GitService({
    required this.projectName,
    required this.repoUrl,
    required this.token,
  });

  Directory get _projectDir => StorageService.projectDir(projectName);

  Future<ProcessResult> _runGit(List<String> args) async {
    return await Process.run("git", args,
        workingDirectory: _projectDir.path);
  }

  Future<bool> _isGitRepo() async {
    return await Directory("${_projectDir.path}/.git").exists();
  }

  Future<String> clone() async {
    if (await _projectDir.exists()) {
      await _projectDir.delete(recursive: true);
    }

    final authUrl = repoUrl.replaceFirst("https://", "https://$token@");
    final result = await Process.run(
        "git", ["clone", "--depth", "1", authUrl, _projectDir.path]);

    if (result.exitCode != 0) {
      return "Clone failed: ${result.stderr}";
    }
    return "Cloned $repoUrl";
  }

  Future<String> pull() async {
    if (!await _isGitRepo()) {
      return "Not a git repository";
    }

    final result = await _runGit(["pull", "--rebase"]);
    if (result.exitCode != 0) {
      return "Pull failed: ${result.stderr}";
    }
    final stdout = (result.stdout as String).trim();
    return stdout.isEmpty ? "Already up to date" : stdout;
  }

  Future<String> commitAndPush(String message) async {
    if (!await _isGitRepo()) {
      return "Not a git repository";
    }

    await _runGit([;
      "config",
      "user.name",
      SettingsService.githubUser,
    ]);
    await _runGit([;
      "config",
      "user.email",
      "${SettingsService.githubUser}@opencode.mobile",
    ]);

    final statusResult = await _runGit(["status", "--porcelain"]);
    if ((statusResult.stdout as String).trim().isEmpty) {
      return "Nothing to commit";
    }

    await _runGit(["add", "-A"]);

    final commitResult = await _runGit(["commit", "-m", message]);
    if (commitResult.exitCode != 0) {
      final out = (commitResult.stdout as String) +;
          (commitResult.stderr as String);
      if (out.contains("nothing to commit")) {
        return "Nothing to commit";
      }
      return "Commit failed: $out";
    }

    final pushResult = await _runGit(["push"]);
    if (pushResult.exitCode != 0) {
      return "Push failed: ${pushResult.stderr}";
    }

    return "Committed and pushed: $message";
  }

  Future<String> getStatus() async {
    if (!await _isGitRepo()) {
      return "Not a git repository";
    }

    final result = await _runGit(["status", "--short"]);
    final output = (result.stdout as String).trim();
    return output.isEmpty ? "No changes" : output;
  }

  Future<List<String>> getLog({int limit = 5}) async {
    if (!await _isGitRepo()) {
      return ["No commits yet"];
    }

    final result = await _runGit(["log", "--oneline", "-n", "$limit"]);
    return (result.stdout as String);
        .trim();
        .split("\n");
        .where((l) => l.isNotEmpty);
        .toList();
  }
}

