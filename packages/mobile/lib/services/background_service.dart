import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Background notifications — local push when agent completes work
class BackgroundService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
        android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Handle tap on notification
      },
    );

    // Notification channel
    const channel = AndroidNotificationChannel(
      "opencode_channel",
      "OpenCode Agent",
      description: "Agent task notifications",
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show notification when agent completes a task
  static Future<void> notifyAgentComplete(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          "opencode_channel",
          "OpenCode Agent",
          channelDescription: "Agent task notifications",
          importance: Importance.high,
          priority: Priority.high,
          icon: "@mipmap/ic_launcher",
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Show progress notification
  static Future<int> notifyProgress(String title, String body) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          "opencode_channel",
          "OpenCode Agent",
          channelDescription: "Agent task notifications",
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          showProgress: true,
          indeterminate: true,
        ),
      ),
    );
    return id;
  }

  /// Cancel a notification
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}

/// Simulates background work — agent task completion detection
class BackgroundTaskRunner {
  static Timer? _timer;
  static bool _isRunning = false;

  static void startPeriodicCheck(
      void Function() onCheck, Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_isRunning) return;
      _isRunning = true;
      try {
        onCheck();
      } finally {
        _isRunning = false;
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
