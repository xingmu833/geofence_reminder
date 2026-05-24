import 'package:flutter/services.dart';

import 'app_settings_store.dart';

class PickedAlarmAudio {
  const PickedAlarmAudio({required this.name, required this.uri});

  final String name;
  final String uri;
}

class AlarmAudioService {
  const AlarmAudioService();

  static const MethodChannel _channel = MethodChannel(
    'geofence_reminder/alarm_audio',
  );

  Future<void> start(AlarmSoundSetting sound) async {
    try {
      await _channel.invokeMethod<void>('startAlarmSound', sound.toMap());
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopAlarmSound');
    } catch (_) {}
  }

  Future<PickedAlarmAudio?> pickLocalAudio() async {
    final result = await _channel.invokeMapMethod<String, String>(
      'pickAlarmAudio',
    );
    if (result == null) {
      return null;
    }
    final uri = result['uri'];
    if (uri == null || uri.isEmpty) {
      return null;
    }
    return PickedAlarmAudio(name: result['name'] ?? 'Local audio', uri: uri);
  }
}
