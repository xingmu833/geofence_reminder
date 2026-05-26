import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import '../models/strong_reminder_payload.dart';
import 'alarm_audio_service.dart';
import 'app_navigation_service.dart';
import 'app_settings_store.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _strongReminderLaunchChannel = MethodChannel(
    'geofence_reminder/strong_reminder_launch',
  );
  static bool _initialized = false;
  static bool _timezoneInitialized = false;
  static Future<void>? _initializing;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final initializing = _initializing;
    if (initializing != null) {
      return initializing;
    }

    _initializing = _initialize();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> _initialize() async {
    _initializeTimezone();
    _strongReminderLaunchChannel.setMethodCallHandler((call) async {
      if (call.method == 'showStrongReminder') {
        final payload = _payloadFromNativeMap(call.arguments);
        if (payload != null) {
          AppNavigationService.showStrongReminder(payload);
        }
      }
    });
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
    await _handleLaunchFromNativeStrongReminder();

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
        'geofence_alarm_vibration_v5',
        '强提醒',
        description: '以高优先级通知提醒到达地点',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'geofence_alarm_silent_v5',
        '强提醒（无震动）',
        description: '以高优先级通知提醒到达地点',
        importance: Importance.max,
        playSound: true,
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
      isAlarm ? 'v5' : 'v2',
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
    );

    await _plugin.show(
      _notificationId(id),
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: isAlarm ? _encodeStrongReminderPayload(id, title, body) : null,
    );

    if (isAlarm) {
      await const AlarmAudioService().start(settings.alarmSound);
    }

    if (isAlarm && _shouldOpenStrongReminderInForeground()) {
      AppNavigationService.showStrongReminder(
        StrongReminderPayload(id: id, title: title, body: body),
      );
    }
  }

  static Future<void> scheduleSnoozeStrongReminder({
    required StrongReminderPayload payload,
    required Duration delay,
  }) async {
    await initialize();
    final settings = await (const AppSettingsStore()).load();
    final id = _notificationId(payload.id + delay.inMinutes * 100000);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'geofence_alarm_${settings.vibrationEnabled ? 'vibration' : 'silent'}_v5',
        '强提醒',
        icon: 'ic_stat_reminder',
        channelDescription: '稍后再次强提醒',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        ticker: '强提醒',
        playSound: true,
        enableVibration: settings.vibrationEnabled,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        additionalFlags: Int32List.fromList(const [4]),
      ),
    );
    final scheduledAt = tz.TZDateTime.from(DateTime.now().add(delay), tz.local);
    final encodedPayload = _encodeStrongReminderPayload(
      id,
      payload.title,
      payload.body,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        payload.title,
        payload.body,
        scheduledAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: encodedPayload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        payload.title,
        payload.body,
        scheduledAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: encodedPayload,
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

  static void _initializeTimezone() {
    if (_timezoneInitialized) {
      return;
    }
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }

  static Future<void> _handleLaunchFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && response != null) {
      _handleNotificationResponse(response);
    }
  }

  static Future<void> _handleLaunchFromNativeStrongReminder() async {
    try {
      final payload = _payloadFromNativeMap(
        await _strongReminderLaunchChannel.invokeMethod<Object?>(
          'consumeInitialStrongReminder',
        ),
      );
      if (payload != null) {
        AppNavigationService.showStrongReminder(payload);
      }
    } catch (_) {}
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

  static StrongReminderPayload? _payloadFromNativeMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = raw['id'];
    final title = raw['title'];
    final body = raw['body'];
    return StrongReminderPayload(
      id: Reminder.normalizeId(id is int ? id : int.tryParse('$id') ?? 0),
      title: title as String? ?? '强提醒',
      body: body as String? ?? '',
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  // The UI navigator is not available in the background isolate.
}
