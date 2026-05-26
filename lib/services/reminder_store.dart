import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

class ReminderStore {
  const ReminderStore();

  static const _storageKey = 'reminders.v1';
  static const _trashStorageKey = 'reminders.trash.v1';
  static const _maxTrashCount = 50;
  static const _demoReminderIds = {1, 2, 3};

  Future<List<Reminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      await saveReminders(const []);
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final reminders = decoded
          .whereType<Map>()
          .map((item) => Reminder.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final withoutDemoReminders = reminders
          .where((item) => !_demoReminderIds.contains(item.id))
          .toList();
      final normalizedReminders = withoutDemoReminders
          .map(
            (item) => item.triggerLimit == TriggerLimit.once &&
                    item.lastTriggeredAt != null &&
                    item.isEnabled
                ? item.copyWith(isEnabled: false)
                : item,
          )
          .toList();
      if (normalizedReminders.length != reminders.length ||
          normalizedReminders.asMap().entries.any((entry) {
            final original = withoutDemoReminders[entry.key];
            return original.isEnabled != entry.value.isEnabled;
          })) {
        await saveReminders(normalizedReminders);
      }
      return normalizedReminders;
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

  Future<List<Reminder>> loadTrashReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trashStorageKey);
    if (raw == null) {
      return const [];
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

  Future<void> saveTrashReminders(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      reminders.take(_maxTrashCount).map((reminder) => reminder.toJson()).toList(),
    );
    await prefs.setString(_trashStorageKey, raw);
  }

  Future<void> moveToTrash(Reminder reminder) async {
    final trash = await loadTrashReminders();
    final next = [
      reminder.copyWith(isInsideGeofence: false),
      ...trash.where((item) => item.id != reminder.id),
    ].take(_maxTrashCount).toList();
    await saveTrashReminders(next);
  }

  Future<List<Reminder>> restoreFromTrash(Iterable<int> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) {
      return loadReminders();
    }

    final reminders = await loadReminders();
    final trash = await loadTrashReminders();
    final restoring = trash.where((item) => idSet.contains(item.id)).toList();
    final keptTrash = trash.where((item) => !idSet.contains(item.id)).toList();
    final restored = [
      ...restoring,
      ...reminders.where((item) => !idSet.contains(item.id)),
    ];

    await saveReminders(restored);
    await saveTrashReminders(keptTrash);
    return restored;
  }

  Future<void> deleteTrashReminders(Iterable<int> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) {
      return;
    }

    final trash = await loadTrashReminders();
    await saveTrashReminders(
      trash.where((item) => !idSet.contains(item.id)).toList(),
    );
  }

  Future<List<Reminder>> restoreAllTrashReminders() async {
    final trash = await loadTrashReminders();
    return restoreFromTrash(trash.map((item) => item.id));
  }

  Future<void> clearTrashReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trashStorageKey, jsonEncode([]));
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
