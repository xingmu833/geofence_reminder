import 'dart:math' as math;

import '../models/reminder.dart';
import 'native_geofence_bridge.dart';
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

  static const Duration _scanTriggerCooldown = Duration(seconds: 30);
  static const NativeGeofenceBridge _native = NativeGeofenceBridge();
  static bool _isScanningLocation = false;
  static String? _lastSyncedSignature;

  Future<void> initialize() async {
    await NotificationService.initialize();
  }

  Future<void> syncReminders(List<Reminder> reminders) async {
    await initialize();
    final signature = _buildSyncSignature(reminders);
    if (_lastSyncedSignature == signature) {
      return;
    }
    await _native.syncReminders(reminders);
    _lastSyncedSignature = signature;
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
      await _native.removeGeofence(reminderId);
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
    bool useCooldown = true,
  }) async {
    try {
      final location = await _native.getCurrentPosition();
      return triggerMatchingStoredRemindersAt(
        latitude: location.latitude,
        longitude: location.longitude,
        useCooldown: useCooldown,
      );
    } catch (_) {
      return 0;
    }
  }

  Future<ImmediateTriggerResult> triggerMatchingCurrentLocation(
    List<Reminder> reminders, {
    int? onlyReminderId,
  }) async {
    await initialize();

    final location = await _native.getCurrentPosition();
    return _triggerMatchingAt(
      reminders,
      latitude: location.latitude,
      longitude: location.longitude,
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
        blockedReason ??= 'current_location_outside_radius';
        continue;
      }

      if (!triggerOnEntry) {
        if (reminder.isInsideGeofence != isInside) {
          updated[i] = reminder.markInsideGeofence(isInside);
          stateChangedCount++;
        }
        blockedReason ??= 'already_inside_waiting_for_next_entry';
        continue;
      }

      if (reminder.isInsideGeofence) {
        blockedReason ??= 'already_inside';
        continue;
      }

      if (!reminder.isEnabled) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= 'reminder_paused';
        continue;
      }
      if (!reminder.isScheduleActiveAt(now)) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= 'outside_schedule';
        continue;
      }
      if (reminder.triggerLimit == TriggerLimit.once &&
          reminder.lastTriggeredAt != null) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= 'already_triggered_once';
        continue;
      }
      if (reminder.triggerLimit == TriggerLimit.daily &&
          reminder.dailyTriggerDate != null &&
          _isSameDay(reminder.dailyTriggerDate!, now) &&
          reminder.dailyTriggeredCount >= reminder.dailyTriggerLimit) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= 'daily_limit_reached';
        continue;
      }
      if (useCooldown &&
          reminder.lastTriggeredAt != null &&
          now.difference(reminder.lastTriggeredAt!) < _scanTriggerCooldown) {
        updated[i] = reminder.markInsideGeofence(true);
        stateChangedCount++;
        blockedReason ??= 'cooldown';
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
        await _native.removeGeofence(reminder.id);
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

  static String _buildSyncSignature(List<Reminder> reminders) {
    final sorted = [...reminders]..sort((a, b) => a.id.compareTo(b.id));
    final buffer = StringBuffer();
    for (final reminder in sorted) {
      buffer
        ..write(reminder.id)
        ..write('|')
        ..write(reminder.isEnabled)
        ..write('|')
        ..write(reminder.latitude.toStringAsFixed(6))
        ..write('|')
        ..write(reminder.longitude.toStringAsFixed(6))
        ..write('|')
        ..write(reminder.radiusMeters)
        ..write('|')
        ..write(reminder.triggerLimit.name)
        ..write('|')
        ..write(reminder.dailyTriggerLimit)
        ..write('|')
        ..write(reminder.scheduleLabel)
        ..write('|')
        ..write(reminder.alertMode.name)
        ..write('|')
        ..write(reminder.isInsideGeofence)
        ..write('|')
        ..write(reminder.lastTriggeredAt?.toIso8601String() ?? '')
        ..write('|')
        ..write(reminder.dailyTriggerDate?.toIso8601String() ?? '')
        ..write('|')
        ..write(reminder.dailyTriggeredCount)
        ..write(';');
    }
    return buffer.toString();
  }
}
