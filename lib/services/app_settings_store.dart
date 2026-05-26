import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.vibrationEnabled,
    required this.repeatReminderEnabled,
    required this.alarmSound,
    required this.exportedRulesJson,
  });

  final bool vibrationEnabled;
  final bool repeatReminderEnabled;
  final AlarmSoundSetting alarmSound;
  final String? exportedRulesJson;

  AppSettingsSnapshot copyWith({
    bool? vibrationEnabled,
    bool? repeatReminderEnabled,
    AlarmSoundSetting? alarmSound,
    Object? exportedRulesJson = _unset,
  }) {
    return AppSettingsSnapshot(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      repeatReminderEnabled:
          repeatReminderEnabled ?? this.repeatReminderEnabled,
      alarmSound: alarmSound ?? this.alarmSound,
      exportedRulesJson: exportedRulesJson == _unset
          ? this.exportedRulesJson
          : exportedRulesJson as String?,
    );
  }

  static const Object _unset = Object();
}

enum AlarmSoundSource { builtIn, localFile }

class AlarmSoundSetting {
  const AlarmSoundSetting({
    required this.source,
    required this.id,
    required this.name,
    this.uri,
  });

  final AlarmSoundSource source;
  final String id;
  final String name;
  final String? uri;

  static const defaultValue = AlarmSoundSetting(
    source: AlarmSoundSource.builtIn,
    id: 'alarm_chime',
    name: '清脆铃声',
  );

  static const builtInSounds = [
    AlarmSoundSetting(
      source: AlarmSoundSource.builtIn,
      id: 'alarm_chime',
      name: '清脆铃声',
    ),
    AlarmSoundSetting(
      source: AlarmSoundSource.builtIn,
      id: 'alarm_beep',
      name: '短促提示',
    ),
    AlarmSoundSetting(
      source: AlarmSoundSource.builtIn,
      id: 'alarm_rise',
      name: '渐进提示',
    ),
  ];

  String get label => source == AlarmSoundSource.localFile ? '本地音频：$name' : name;

  Map<String, String> toMap() {
    return {
      'source': source.name,
      'id': id,
      'name': name,
      'uri': ?uri,
    };
  }

  factory AlarmSoundSetting.fromMap(Map<String, dynamic> map) {
    final sourceName = map['source'] as String?;
    final source = AlarmSoundSource.values.firstWhere(
      (item) => item.name == sourceName,
      orElse: () => AlarmSoundSource.builtIn,
    );
    final id = map['id'] as String? ?? defaultValue.id;
    if (source == AlarmSoundSource.builtIn) {
      return builtInSounds.firstWhere(
        (item) => item.id == id,
        orElse: () => defaultValue,
      );
    }
    return AlarmSoundSetting(
      source: AlarmSoundSource.localFile,
      id: id,
      name: map['name'] as String? ?? '本地音频',
      uri: map['uri'] as String?,
    );
  }
}

class AppSettingsStore {
  const AppSettingsStore();

  static const _vibrationKey = 'settings.vibrationEnabled';
  static const _repeatKey = 'settings.repeatReminderEnabled';
  static const _alarmSoundSourceKey = 'settings.alarmSound.source';
  static const _alarmSoundIdKey = 'settings.alarmSound.id';
  static const _alarmSoundNameKey = 'settings.alarmSound.name';
  static const _alarmSoundUriKey = 'settings.alarmSound.uri';
  static const _exportedRulesKey = 'settings.exportedRulesJson';

  Future<AppSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmSound = AlarmSoundSetting.fromMap({
      'source': prefs.getString(_alarmSoundSourceKey),
      'id': prefs.getString(_alarmSoundIdKey),
      'name': prefs.getString(_alarmSoundNameKey),
      'uri': prefs.getString(_alarmSoundUriKey),
    });
    return AppSettingsSnapshot(
      vibrationEnabled: prefs.getBool(_vibrationKey) ?? true,
      repeatReminderEnabled: prefs.getBool(_repeatKey) ?? false,
      alarmSound: alarmSound,
      exportedRulesJson: prefs.getString(_exportedRulesKey),
    );
  }

  Future<void> save(AppSettingsSnapshot settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, settings.vibrationEnabled);
    await prefs.setBool(_repeatKey, settings.repeatReminderEnabled);
    final alarmSound = settings.alarmSound;
    await prefs.setString(_alarmSoundSourceKey, alarmSound.source.name);
    await prefs.setString(_alarmSoundIdKey, alarmSound.id);
    await prefs.setString(_alarmSoundNameKey, alarmSound.name);
    if (alarmSound.uri == null) {
      await prefs.remove(_alarmSoundUriKey);
    } else {
      await prefs.setString(_alarmSoundUriKey, alarmSound.uri!);
    }
    if (settings.exportedRulesJson == null) {
      await prefs.remove(_exportedRulesKey);
    } else {
      await prefs.setString(_exportedRulesKey, settings.exportedRulesJson!);
    }
  }
}
