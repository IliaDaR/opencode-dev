/// Permission system — allow/ask/deny per tool
class PermissionService {
  static final Map<String, String> _rules = {
    "read_file": "allow",
    "write_file": "allow",
    "edit_file": "allow",
    "delete_file": "ask",
    "list_files": "allow",
    "glob_files": "allow",
    "search_code": "allow",
    "run_command": "ask",
    "git_sync": "allow",
    "git_status": "allow",
    "web_search": "allow",
    "web_fetch": "allow",
    "browser_open": "allow",
    "browser_extract": "allow",
    "browser_follow": "allow",
    "sql_detect": "allow",
    "sql_query": "allow",
    "sql_schema": "allow",
    "github_list_issues": "allow",
    "github_create_issue": "ask",
    "github_list_prs": "allow",
    "github_get_pr": "allow",
    "github_search_code": "allow",
    "github_get_file": "allow",
    "github_get_repo": "allow",
    "diagnose_file": "allow",
    "analyze_project": "allow",
    "check_imports": "allow",
    "find_patterns": "allow",
    "suggest_tests": "allow",
    "suggest_optimizations": "allow",
    "generate_test_template": "allow",
    "generate_boilerplate": "allow",
    "impact_analysis": "allow",
    "delegate_task": "allow",
    "estimate_effort": "allow",
    "generate_readme": "allow",
    "generate_api_docs": "allow",
    "check_deploy_readiness": "allow",
    "generate_docker_compose": "allow",
    "generate_ci_config": "allow",
    "create_tasks": "allow",
    "ask_user": "allow",
    "snapshot_undo": "allow",
    "format_code": "allow",
    "batch_execute": "allow",
  };

  static String get(String tool) => _rules[tool] ?? "allow";

  static void set(String tool, String action) {
    _rules[tool] = action;
  }

  /// Check if tool needs user confirmation
  static bool needsAsk(String tool) => get(tool) == "ask";

  /// Check if tool is denied
  static bool isDenied(String tool) => get(tool) == "deny";
}
