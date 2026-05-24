import 'package:flutter/services.dart';

import '../models/reminder.dart';

class NativePosition {
  const NativePosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class NativeGeofenceBridge {
  const NativeGeofenceBridge();

  static const MethodChannel _channel = MethodChannel(
    'geofence_reminder/geofence',
  );

  Future<void> syncReminders(List<Reminder> reminders) async {
    await _channel.invokeMethod<void>(
      'syncGeofences',
      reminders.where((item) => item.isEnabled).map(_toNativeMap).toList(),
    );
  }

  Future<void> removeGeofence(int reminderId) async {
    await _channel.invokeMethod<void>('removeGeofence', {'id': reminderId});
  }

  Future<void> showTestAlarm() async {
    await _channel.invokeMethod<void>('showTestAlarm');
  }

  Future<NativePosition> getCurrentPosition() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'getCurrentPosition',
    );
    final latitude = result?['latitude'];
    final longitude = result?['longitude'];
    if (latitude is num && longitude is num) {
      return NativePosition(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      );
    }
    throw PlatformException(
      code: 'location_unavailable',
      message: 'Unable to read current location',
    );
  }

  Map<String, Object?> _toNativeMap(Reminder reminder) {
    return {
      'id': reminder.id,
      'title': reminder.title,
      'locationName': reminder.locationName,
      'latitude': reminder.latitude,
      'longitude': reminder.longitude,
      'radiusMeters': reminder.radiusMeters,
      'isEnabled': reminder.isEnabled,
      'triggerLimit': reminder.triggerLimit.name,
      'dailyTriggerLimit': reminder.dailyTriggerLimit,
      'scheduleLabel': reminder.scheduleLabel,
      'alertMode': reminder.alertMode.name,
      'createdAt': reminder.createdAt.toIso8601String(),
      if (reminder.lastTriggeredAt != null)
        'lastTriggeredAt': reminder.lastTriggeredAt!.toIso8601String(),
      if (reminder.lastTriggeredLabel != null)
        'lastTriggeredLabel': reminder.lastTriggeredLabel,
      'dailyTriggeredCount': reminder.dailyTriggeredCount,
      if (reminder.dailyTriggerDate != null)
        'dailyTriggerDate': reminder.dailyTriggerDate!.toIso8601String(),
      'isInsideGeofence': reminder.isInsideGeofence,
    };
  }
}
