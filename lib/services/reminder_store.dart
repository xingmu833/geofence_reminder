import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

class ReminderStore {
  const ReminderStore();

  static const _storageKey = 'reminders.v1';

  Future<List<Reminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      final defaultReminders = Reminder.demoList();
      await saveReminders(defaultReminders);
      return defaultReminders;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Reminder.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      reminders.map((reminder) => reminder.toJson()).toList(),
    );
    await prefs.setString(_storageKey, raw);
  }

  Future<String> exportJson() async {
    final reminders = await loadReminders();
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(reminders.map((reminder) => reminder.toJson()).toList());
  }

  Future<void> clearReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode([]));
  }
}
