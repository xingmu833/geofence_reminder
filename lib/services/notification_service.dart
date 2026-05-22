import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/reminder.dart';
import '../models/strong_reminder_payload.dart';
import 'app_navigation_service.dart';
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

    const androidSettings = AndroidInitializationSettings('ic_stat_reminder');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestFullScreenIntentPermission();
    await _createAndroidChannels(android);
    await _handleLaunchFromNotification();

    _initialized = true;
  }

  static Future<void> _createAndroidChannels(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) {
      return;
    }
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'geofence_notification_vibration_v2',
        '位置提醒',
        description: '到达提醒地点时弹出的普通通知',
        importance: Importance.high,
        enableVibration: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'geofence_notification_silent_v2',
        '位置提醒（无震动）',
        description: '到达提醒地点时弹出的普通通知',
        importance: Importance.high,
        enableVibration: false,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'geofence_alarm_vibration_v3',
        '强提醒',
        description: '以高优先级通知提醒到达地点',
        importance: Importance.max,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'geofence_alarm_silent_v3',
        '强提醒（无震动）',
        description: '以高优先级通知提醒到达地点',
        importance: Importance.max,
        enableVibration: false,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  static Future<void> showReminder(Reminder reminder) async {
    await showGeofenceReminder(
      id: reminder.id,
      title: reminder.alertMode == AlertMode.alarm ? '到达提醒地点' : '位置提醒',
      body: reminder.title,
      alertMode: reminder.alertMode,
    );
  }

  static Future<void> showGeofenceReminder({
    required int id,
    required String title,
    required String body,
    AlertMode alertMode = AlertMode.notification,
  }) async {
    await initialize();
    final settings = await (const AppSettingsStore()).load();
    final isAlarm = alertMode == AlertMode.alarm;
    final channelId = [
      isAlarm ? 'geofence_alarm' : 'geofence_notification',
      settings.vibrationEnabled ? 'vibration' : 'silent',
      isAlarm ? 'v3' : 'v2',
    ].join('_');

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isAlarm ? '强提醒' : '位置提醒',
      icon: 'ic_stat_reminder',
      channelDescription: isAlarm
          ? '以高优先级通知提醒到达地点'
          : '到达提醒地点时弹出的普通通知',
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      category: isAlarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      ticker: '位置提醒',
      playSound: true,
      enableVibration: settings.vibrationEnabled,
      fullScreenIntent: isAlarm,
      audioAttributesUsage: isAlarm
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      visibility: NotificationVisibility.public,
      ongoing: isAlarm,
      autoCancel: !isAlarm,
      additionalFlags: isAlarm ? Int32List.fromList(const [4]) : null,
      actions: isAlarm
          ? const [
              AndroidNotificationAction(
                'dismiss',
                '知道了',
                cancelNotification: true,
              ),
            ]
          : null,
    );

    await _plugin.show(
      _notificationId(id),
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: isAlarm ? _encodeStrongReminderPayload(id, title, body) : null,
    );

    if (isAlarm && _shouldOpenStrongReminderInForeground()) {
      AppNavigationService.showStrongReminder(
        StrongReminderPayload(id: id, title: title, body: body),
      );
    }
  }

  static int _notificationId(int id) {
    return Reminder.normalizeId(id);
  }

  static Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(_notificationId(id));
  }

  static bool _shouldOpenStrongReminderInForeground() {
    try {
      return WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed &&
          AppNavigationService.navigatorKey.currentState != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _handleLaunchFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && response != null) {
      _handleNotificationResponse(response);
    }
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'dismiss') {
      return;
    }

    final payload = _decodeStrongReminderPayload(response.payload);
    if (payload != null) {
      AppNavigationService.showStrongReminder(payload);
    }
  }

  static String _encodeStrongReminderPayload(int id, String title, String body) {
    return jsonEncode({
      'type': 'strong_reminder',
      'id': id,
      'title': title,
      'body': body,
    });
  }

  static StrongReminderPayload? _decodeStrongReminderPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic> || json['type'] != 'strong_reminder') {
        return null;
      }
      return StrongReminderPayload(
        id: Reminder.normalizeId(int.tryParse('${json['id']}') ?? 0),
        title: json['title'] as String? ?? '强提醒',
        body: json['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  // The UI navigator is not available in the background isolate.
}
