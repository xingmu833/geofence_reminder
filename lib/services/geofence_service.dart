import 'dart:math' as math;

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../models/reminder.dart';
import 'notification_service.dart';
import 'reminder_store.dart';

class ImmediateTriggerResult {
  const ImmediateTriggerResult({
    required this.reminders,
    required this.triggeredCount,
    required this.checkedCount,
    this.stateChangedCount = 0,
    this.closestDistanceMeters,
    this.blockedReason,
  });

  final List<Reminder> reminders;
  final int triggeredCount;
  final int checkedCount;
  final int stateChangedCount;
  final double? closestDistanceMeters;
  final String? blockedReason;

  bool get hasChanges => triggeredCount > 0 || stateChangedCount > 0;
}

class AppGeofenceService {
  const AppGeofenceService();

  static const Duration _scanTriggerCooldown = Duration(minutes: 10);
  static bool _ready = false;
  static bool _isScanningLocation = false;

  Future<void> initialize() async {
    await NotificationService.initialize();

    if (_ready) {
      return;
    }

    bg.BackgroundGeolocation.onGeofence((bg.GeofenceEvent event) async {
      final reminderId = _reminderIdFromIdentifier(event.identifier);
      if (reminderId == null) {
        return;
      }

      if (event.action == 'ENTER') {
        await triggerReminderById(reminderId);
      } else if (event.action == 'EXIT') {
        await markReminderOutside(reminderId);
      }
    });

    bg.BackgroundGeolocation.onLocation(
      (bg.Location location) async {
        await triggerMatchingStoredRemindersAt(
          latitude: location.coords.latitude,
          longitude: location.coords.longitude,
          useCooldown: true,
        );
      },
      (bg.LocationError error) {},
    );

    bg.BackgroundGeolocation.onMotionChange((bg.Location location) async {
      await triggerMatchingStoredRemindersAt(
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        useCooldown: true,
      );
    });

    bg.BackgroundGeolocation.onHeartbeat((bg.HeartbeatEvent event) async {
      await triggerMatchingBestAvailablePosition(
        fallbackLocation: event.location,
        useCooldown: true,
      );
    });

    final state = await bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 25,
        heartbeatInterval: 60,
        foregroundService: true,
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
      await bg.BackgroundGeolocation.start();
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
          notifyOnExit: true,
          extras: {
            'title': reminder.title,
            'locationName': reminder.locationName,
            'alertMode': reminder.alertMode.name,
          },
        ),
      );
    }

    if (enabledReminders.isNotEmpty) {
      await bg.BackgroundGeolocation.start();
    }
  }

  Future<void> triggerReminderById(int reminderId) async {
    final store = const ReminderStore();
    final reminders = await store.loadReminders();
    final index = reminders.indexWhere((item) => item.id == reminderId);
    if (index == -1) {
      return;
    }

    final now = DateTime.now();
    final reminder = reminders[index];
    if (reminder.isInsideGeofence) {
      return;
    }
    if (!reminder.canTriggerAt(now)) {
      final updated = [...reminders];
      updated[index] = reminder.markInsideGeofence(true);
      await store.saveReminders(updated);
      return;
    }

    await NotificationService.showReminder(reminder);
    final updated = [...reminders];
    updated[index] = reminder.markTriggered(now);
    await store.saveReminders(updated);
    if (!updated[index].isEnabled) {
      await bg.BackgroundGeolocation.removeGeofence('reminder-$reminderId');
    }
  }

  Future<void> markReminderOutside(int reminderId) async {
    final store = const ReminderStore();
    final reminders = await store.loadReminders();
    final index = reminders.indexWhere((item) => item.id == reminderId);
    if (index == -1 || !reminders[index].isInsideGeofence) {
      return;
    }

    final updated = [...reminders];
    updated[index] = reminders[index].markInsideGeofence(false);
    await store.saveReminders(updated);
  }

  Future<int> triggerMatchingStoredRemindersAt({
    required double latitude,
    required double longitude,
    bool useCooldown = false,
  }) async {
    if (_isScanningLocation) {
      return 0;
    }
    _isScanningLocation = true;
    try {
      final store = const ReminderStore();
      final reminders = await store.loadReminders();
      final result = await _triggerMatchingAt(
        reminders,
        latitude: latitude,
        longitude: longitude,
        useCooldown: useCooldown,
      );
      if (result.hasChanges) {
        await store.saveReminders(result.reminders);
        await _removePausedTriggeredGeofences(result.reminders, reminders);
      }
      return result.triggeredCount;
    } finally {
      _isScanningLocation = false;
    }
  }

  Future<int> triggerMatchingBestAvailablePosition({
    bg.Location? fallbackLocation,
    bool useCooldown = true,
  }) async {
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        timeout: 15,
        maximumAge: 30000,
        persist: false,
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      );
      return triggerMatchingStoredRemindersAt(
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        useCooldown: useCooldown,
      );
    } catch (_) {
      final location = fallbackLocation;
      if (location == null) {
        return 0;
      }
      return triggerMatchingStoredRemindersAt(
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        useCooldown: useCooldown,
      );
    }
  }

  Future<ImmediateTriggerResult> triggerMatchingCurrentLocation(
    List<Reminder> reminders, {
    int? onlyReminderId,
  }) async {
    await initialize();

    final location = await bg.BackgroundGeolocation.getCurrentPosition(
      samples: 2,
      timeout: 30,
      maximumAge: 5000,
      persist: false,
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
    );

    return _triggerMatchingAt(
      reminders,
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      onlyReminderId: onlyReminderId,
      useCooldown: false,
      triggerOnEntry: false,
    );
  }

  Future<ImmediateTriggerResult> _triggerMatchingAt(
    List<Reminder> reminders, {
    required double latitude,
    required double longitude,
    int? onlyReminderId,
    required bool useCooldown,
    bool triggerOnEntry = true,
  }) async {
    final now = DateTime.now();
    final updated = [...reminders];
    var triggeredCount = 0;
    var checkedCount = 0;
    var stateChangedCount = 0;
    double? closestDistanceMeters;
    String? blockedReason;

    for (var i = 0; i < updated.length; i++) {
      final reminder = updated[i];
      if (onlyReminderId != null && reminder.id != onlyReminderId) {
        continue;
      }

      final distance = _distanceMeters(
        latitude,
        longitude,
        reminder.latitude,
        reminder.longitude,
      );
      checkedCount++;
      if (closestDistanceMeters == null || distance < closestDistanceMeters) {
        closestDistanceMeters = distance;
      }

      final isInside = distance <= reminder.radiusMeters;
      if (!isInside) {
        if (reminder.isInsideGeofence) {
          updated[i] = reminder.markInsideGeofence(false);
          stateChangedCount++;
        }
        blockedReason ??= '当前位置不在提醒半径内';
        continue;
      }

      if (!triggerOnEntry) {
        if (reminder.isInsideGeofence != isInside) {
          updated[i] = reminder.markInsideGeofence(isInside);
          stateChangedCount++;
        }
        blockedReason ??= '当前位置已在提醒范围内，等待下次从范围外进入时触发';
        continue;
      }

      if (reminder.isInsideGeofence) {
        blockedReason ??= '当前位置已在提醒范围内，离开后再次进入才会触发';
        continue;
      }

      if (!reminder.isEnabled) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= '提醒已暂停';
        continue;
      }
      if (!reminder.isScheduleActiveAt(now)) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= '当前不在设置的响应时间段内';
        continue;
      }
      if (reminder.triggerLimit == TriggerLimit.once &&
          reminder.lastTriggeredAt != null) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= '此提醒已经触发过';
        continue;
      }
      if (reminder.triggerLimit == TriggerLimit.daily &&
          reminder.dailyTriggerDate != null &&
          _isSameDay(reminder.dailyTriggerDate!, now) &&
          reminder.dailyTriggeredCount >= reminder.dailyTriggerLimit) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= '此提醒今天已经达到触发次数';
        continue;
      }
      if (useCooldown &&
          reminder.lastTriggeredAt != null &&
          now.difference(reminder.lastTriggeredAt!) < _scanTriggerCooldown) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= '提醒刚刚触发过';
        continue;
      }

      await NotificationService.showReminder(reminder);
      updated[i] = reminder.markTriggered(now);
      triggeredCount++;
    }

    return ImmediateTriggerResult(
      reminders: updated,
      triggeredCount: triggeredCount,
      checkedCount: checkedCount,
      stateChangedCount: stateChangedCount,
      closestDistanceMeters: closestDistanceMeters,
      blockedReason: blockedReason,
    );
  }

  static int? _reminderIdFromIdentifier(String identifier) {
    return int.tryParse(identifier.replaceFirst('reminder-', ''));
  }

  Future<void> _removePausedTriggeredGeofences(
    List<Reminder> updated,
    List<Reminder> previous,
  ) async {
    for (final reminder in updated) {
      final old = previous.firstWhere(
        (item) => item.id == reminder.id,
        orElse: () => reminder,
      );
      if (old.isEnabled && !reminder.isEnabled) {
        await bg.BackgroundGeolocation.removeGeofence('reminder-${reminder.id}');
      }
    }
  }

  static double _distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadius = 6371000.0;
    final startLat = _toRadians(startLatitude);
    final endLat = _toRadians(endLatitude);
    final deltaLat = _toRadians(endLatitude - startLatitude);
    final deltaLng = _toRadians(endLongitude - startLongitude);
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(startLat) *
            math.cos(endLat) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
