import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../models/reminder.dart';
import 'notification_service.dart';

class AppGeofenceService {
  const AppGeofenceService();

  static bool _ready = false;

  Future<void> initialize() async {
    await NotificationService.initialize();

    bg.BackgroundGeolocation.onGeofence((bg.GeofenceEvent event) async {
      if (event.action != 'ENTER') {
        return;
      }

      final identifier = event.identifier;
      final reminderId = int.tryParse(identifier.replaceFirst('reminder-', ''));
      if (reminderId == null) {
        return;
      }

      await NotificationService.showGeofenceReminder(
        id: reminderId,
        title: '到达提醒地点',
        body: event.extras?['title'] as String? ?? '你有一条位置提醒',
      );
    });

    if (_ready) {
      return;
    }

    final state = await bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 25,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        geofenceModeHighAccuracy: true,
        locationAuthorizationRequest: 'Always',
        backgroundPermissionRationale: bg.PermissionRationale(
          title: '允许后台定位',
          message: '临场记需要在后台判断你是否到达提醒地点。',
          positiveAction: '去设置',
          negativeAction: '暂不',
        ),
        notification: bg.Notification(
          title: '临场记正在守护位置提醒',
          text: '到达已设置地点时会提醒你',
          channelName: '后台位置服务',
        ),
        logLevel: bg.Config.LOG_LEVEL_OFF,
      ),
    );

    _ready = true;
    if (!state.enabled) {
      await bg.BackgroundGeolocation.startGeofences();
    }
  }

  Future<void> syncReminders(List<Reminder> reminders) async {
    await initialize();
    await bg.BackgroundGeolocation.removeGeofences();

    final enabledReminders = reminders.where((item) => item.isEnabled);
    for (final reminder in enabledReminders) {
      await bg.BackgroundGeolocation.addGeofence(
        bg.Geofence(
          identifier: 'reminder-${reminder.id}',
          radius: reminder.radiusMeters.toDouble(),
          latitude: reminder.latitude,
          longitude: reminder.longitude,
          notifyOnEntry: true,
          notifyOnExit: false,
          extras: {
            'title': reminder.title,
            'locationName': reminder.locationName,
          },
        ),
      );
    }
  }
}
