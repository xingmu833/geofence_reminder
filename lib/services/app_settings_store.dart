import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.vibrationEnabled,
    required this.repeatReminderEnabled,
    required this.exportedRulesJson,
  });

  final bool vibrationEnabled;
  final bool repeatReminderEnabled;
  final String? exportedRulesJson;

  AppSettingsSnapshot copyWith({
    bool? vibrationEnabled,
    bool? repeatReminderEnabled,
    String? exportedRulesJson,
  }) {
    return AppSettingsSnapshot(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      repeatReminderEnabled:
          repeatReminderEnabled ?? this.repeatReminderEnabled,
      exportedRulesJson: exportedRulesJson ?? this.exportedRulesJson,
    );
  }
}

class AppSettingsStore {
  const AppSettingsStore();

  static const _vibrationKey = 'settings.vibrationEnabled';
  static const _repeatKey = 'settings.repeatReminderEnabled';
  static const _exportedRulesKey = 'settings.exportedRulesJson';

  Future<AppSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsSnapshot(
      vibrationEnabled: prefs.getBool(_vibrationKey) ?? true,
      repeatReminderEnabled: prefs.getBool(_repeatKey) ?? false,
      exportedRulesJson: prefs.getString(_exportedRulesKey),
    );
  }

  Future<void> save(AppSettingsSnapshot settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, settings.vibrationEnabled);
    await prefs.setBool(_repeatKey, settings.repeatReminderEnabled);
    if (settings.exportedRulesJson == null) {
      await prefs.remove(_exportedRulesKey);
    } else {
      await prefs.setString(_exportedRulesKey, settings.exportedRulesJson!);
    }
  }
}
