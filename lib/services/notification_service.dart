import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_settings_store.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> showGeofenceReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    final settings = await (const AppSettingsStore()).load();
    final channelId = settings.vibrationEnabled
        ? 'geofence_reminders_vibration'
        : 'geofence_reminders_silent';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      '位置提醒',
      channelDescription: '到达提醒地点时弹出的本地通知',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      ticker: '位置提醒',
      enableVibration: settings.vibrationEnabled,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}
