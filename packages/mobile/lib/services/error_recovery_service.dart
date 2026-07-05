/// Smarter error recovery — when a tool fails, analyze and retry differently
class ErrorRecoveryService {
  /// Classify an error and suggest recovery strategy
  static RecoveryStrategy analyze(String toolName, String errorMessage) {
    final lower = errorMessage.toLowerCase();

    if (lower.contains("not found") || lower.contains("enoent")) {
      return RecoveryStrategy(
        message: "File not found. Check the path with list_files or glob_files first.",
        action: RecoveryAction.suggestAlternative,
        alternative: "Use list_files to browse available files, then retry with the correct path.",
      );
    }

    if (lower.contains("permission") || lower.contains("denied")) {
      return RecoveryStrategy(
        message: "Permission denied. The file may be read-only or outside the project.",
        action: RecoveryAction.suggestAlternative,
        alternative: "Try reading the file with read_file first. If it's outside the project, clone it first.",
      );
    }

    if (lower.contains("already exists")) {
      return RecoveryStrategy(
        message: "File already exists. Use edit_file to modify it instead of write_file.",
        action: RecoveryAction.suggestAlternative,
        alternative: "Use edit_file with old_string/new_string to modify the existing file.",
      );
    }

    if (lower.contains("api") && (lower.contains("429") || lower.contains("rate"))) {
      return RecoveryStrategy(
        message: "Rate limited. Waiting a moment before retry.",
        action: RecoveryAction.retryWithDelay,
      );
    }

    if (lower.contains("timeout") || lower.contains("timed out")) {
      return RecoveryStrategy(
        message: "Operation timed out. The task may be too large.",
        action: RecoveryAction.splitAndRetry,
        alternative: "Try breaking the task into smaller steps.",
      );
    }

    if (lower.contains("old_string not found") || lower.contains("not found in")) {
      return RecoveryStrategy(
        message: "The text to replace was not found. Read the file first to get the exact content.",
        action: RecoveryAction.suggestAlternative,
        alternative: "Use read_file to read the current file content, copy the exact text you want to replace.",
      );
    }

    return RecoveryStrategy(
      message: "Error: $errorMessage",
      action: RecoveryAction.report,
    );
  }
}

enum RecoveryAction {
  retryWithDelay,
  splitAndRetry,
  suggestAlternative,
  report,
}

class RecoveryStrategy {
  final String message;
  final RecoveryAction action;
  final String? alternative;

  RecoveryStrategy({
    required this.message,
    required this.action,
    this.alternative,
  });
}
