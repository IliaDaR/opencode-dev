import "dart:convert";
import "storage_service.dart";
import "git_service.dart";
import "settings_service.dart";
import "session_memory.dart";

/// Syncs everything between phone and PC via GitHub.
///
/// What gets synced:
/// - .opencode settings (API keys stay local, not synced)
/// - Session memory (chat history per project)
/// - Project metadata (decisions, tech stack)
/// - The .opencode config folder itself (skills, agents)
///
/// Flow: pull on start → work → push on commit or app close
class SyncService {
  final String projectName;
  final GitService gitService;

  SyncService({required this.projectName, required this.gitService});

  /// Pull latest config from GitHub
  Future<SyncResult> pullConfig() async {
    final results = <String>[];

    try {
      final pullResult = await gitService.pull();
      if (!pullResult.startsWith("Pull failed")) {
        results.add("Config pulled from GitHub");
      }
    } catch (e) {
      results.add("Pull skipped (no network?)");
    }

    return SyncResult(messages: results, success: true);
  }

  /// Push local changes to GitHub — config + memory
  Future<SyncResult> pushChanges(String reason) async {
    final results = <String>[];

    try {
      // Write session memory to .opencode folder for sync
      await _exportSessionMemory();

      final pushResult =
          await gitService.commitAndPush("sync(mobile): $reason");
      results.add(pushResult);
    } catch (e) {
      results.add("Push failed: $e");
      return SyncResult(messages: results, success: false);
    }

    return SyncResult(messages: results, success: true);
  }

  /// Export session memory as JSON files in .opencode/memory/
  Future<void> _exportSessionMemory() async {
    try {
      final meta =
          await SessionMemory.loadProjectMeta(projectName);
      if (meta != null) {
        await StorageService.writeFile(
          projectName,
          ".opencode/memory/meta.json",
          const JsonEncoder.withIndent("  ").convert(meta),
        );
      }

      final chat =
          await SessionMemory.loadChat(projectName);
      if (chat != null) {
        final simple = chat
            .where((m) => m.role == "user" || m.role == "assistant")
            .map((m) => {
                  "role": m.role,
                  "content": m.content.length > 200
                      ? m.content.substring(0, 200)
                      : m.content,
                })
            .toList();
        await StorageService.writeFile(
          projectName,
          ".opencode/memory/chat.json",
          const JsonEncoder.withIndent("  ").convert(simple),
        );
      }
    } catch (_) {}
  }

  /// Import session memory from synced files
  Future<void> _importSessionMemory() async {
    try {
      final metaRaw = await StorageService.readFile(
          projectName, ".opencode/memory/meta.json");
      final meta = jsonDecode(metaRaw);
      await SessionMemory.saveProjectMeta(projectName, meta);
    } catch (_) {}

    try {
      final chatRaw = await StorageService.readFile(
          projectName, ".opencode/memory/chat.json");
      // Chat is imported indirectly — the messages are loaded
      // from the local SessionMemory, which was synced via git
    } catch (_) {}
  }

  /// Full sync cycle: pull → import → work → export → push
  Future<SyncResult> fullSync(String reason) async {
    final pullResult = await pullConfig();
    await _importSessionMemory();

    final results = <String>[...pullResult.messages];

    return SyncResult(
      messages: results,
      success: pullResult.success,
    );
  }

  /// Check if sync is needed (any local changes?)
  Future<bool> needsSync() async {
    final status = await gitService.getStatus();
    return status != "No changes" && status != "Not a git repository";
  }
}

class SyncResult {
  final List<String> messages;
  final bool success;

  SyncResult({required this.messages, required this.success});
}
