import "package:shared_preferences/shared_preferences.dart";

class SettingsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get deepseekApiKey {
    return _prefs.getString("deepseek_key") ?? "";
  }

  static set deepseekApiKey(String value) {
    _prefs.setString("deepseek_key", value);
  }

  static String get githubToken {
    return _prefs.getString("github_token") ?? "";
  }

  static set githubToken(String value) {
    _prefs.setString("github_token", value);
  }

  static String get githubUser {
    return _prefs.getString("github_user") ?? "";
  }

  static set githubUser(String value) {
    _prefs.setString("github_user", value);
  }

  static String get currentProject {
    return _prefs.getString("current_project") ?? "";
  }

  static set currentProject(String value) {
    _prefs.setString("current_project", value);
  }

  static String get language {
    return _prefs.getString("language") ?? "";
  }

  static set language(String value) {
    _prefs.setString("language", value);
  }

  static void setLanguage(String lang) {
    _prefs.setString("language", lang);
  }

  static bool get isConfigured {
    return deepseekApiKey.isNotEmpty && githubToken.isNotEmpty;
  }
}
