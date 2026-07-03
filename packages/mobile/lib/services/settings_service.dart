import "package:shared_preferences/shared_preferences.dart";

class SettingsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get deepseekApiKey =>;
      _prefs.getString("deepseek_key") ?? "";
  static set deepseekApiKey(String v) =>;
      _prefs.setString("deepseek_key", v);

  static String get githubToken => _prefs.getString("github_token") ?? "";
  static set githubToken(String v) => _prefs.setString("github_token", v);

  static String get githubUser => _prefs.getString("github_user") ?? "";
  static set githubUser(String v) => _prefs.setString("github_user", v);

  static String get currentProject =>;
      _prefs.getString("current_project") ?? "";
  static set currentProject(String v) =>;
      _prefs.setString("current_project", v);

  static bool get isConfigured =>;
      deepseekApiKey.isNotEmpty && githubToken.isNotEmpty;
}

