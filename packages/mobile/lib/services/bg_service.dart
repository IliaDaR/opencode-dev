import "package:flutter_local_notifications/flutter_local_notifications.dart";

/// Background notifications for Android
/// Requires flutter_local_notifications package + Android desugaring setup
class BgService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;

    const android = AndroidInitializationSettings("@mipmap/ic_launcher");
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    const channel = AndroidNotificationChannel(
      "opencode", "OpenCode",
      description: "Agent notifications",
      importance: Importance.high,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  static Future<void> show(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecond,
      title,
      body.length > 100 ? "${body.substring(0, 100)}..." : body,
      const NotificationDetails(
        android: AndroidNotificationDetails("opencode", "OpenCode",
            channelDescription: "Agent notifications",
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
