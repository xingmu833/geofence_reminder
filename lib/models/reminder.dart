enum TriggerLimit { always, once, daily }

enum AlertMode { notification, alarm }

class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isEnabled,
    required this.triggerLimit,
    required this.dailyTriggerLimit,
    required this.scheduleLabel,
    required this.alertMode,
    required this.createdAt,
    this.lastTriggeredAt,
    this.lastTriggeredLabel,
    this.dailyTriggeredCount = 0,
    this.dailyTriggerDate,
    this.isInsideGeofence = false,
  });

  final int id;
  final String title;
  final String locationName;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isEnabled;
  final TriggerLimit triggerLimit;
  final int dailyTriggerLimit;
  final String scheduleLabel;
  final AlertMode alertMode;
  final DateTime createdAt;
  final DateTime? lastTriggeredAt;
  final String? lastTriggeredLabel;
  final int dailyTriggeredCount;
  final DateTime? dailyTriggerDate;
  final bool isInsideGeofence;

  String get radiusLabel {
    if (radiusMeters >= 1000) {
      final value = radiusMeters / 1000;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}km';
    }
    return '${radiusMeters}m';
  }

  String get triggerLimitLabel {
    return switch (triggerLimit) {
      TriggerLimit.always => '每次进入',
      TriggerLimit.once => '仅此一次',
      TriggerLimit.daily => '每天$dailyTriggerLimit次',
    };
  }

  String get alertModeLabel {
    return alertMode == AlertMode.alarm ? '强提醒' : '通知提醒';
  }

  String? get displayLastTriggeredLabel {
    final triggeredAt = lastTriggeredAt;
    if (triggeredAt != null) {
      return _formatTriggerTime(triggeredAt);
    }
    return lastTriggeredLabel;
  }

  bool canTriggerAt(DateTime now) {
    if (!isEnabled || !isScheduleActiveAt(now)) {
      return false;
    }
    if (triggerLimit == TriggerLimit.once && lastTriggeredAt != null) {
      return false;
    }
    if (triggerLimit == TriggerLimit.daily &&
        dailyTriggerDate != null &&
        _isSameDay(dailyTriggerDate!, now) &&
        dailyTriggeredCount >= dailyTriggerLimit) {
      return false;
    }
    return true;
  }

  bool isScheduleActiveAt(DateTime now) {
    if (scheduleLabel == '全天生效') {
      return true;
    }

    final range = _parseScheduleRange(scheduleLabel);
    if (range == null) {
      return true;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = range.startHour * 60 + range.startMinute;
    final endMinutes = range.endHour * 60 + range.endMinute;
    if (startMinutes == endMinutes) {
      return true;
    }
    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
  }

  Reminder markTriggered(DateTime now) {
    final nextDailyCount =
        dailyTriggerDate != null && _isSameDay(dailyTriggerDate!, now)
        ? dailyTriggeredCount + 1
        : 1;
    return copyWith(
      isEnabled: triggerLimit == TriggerLimit.once ? false : isEnabled,
      lastTriggeredAt: now,
      lastTriggeredLabel: _formatTriggerTime(now),
      dailyTriggeredCount: nextDailyCount,
      dailyTriggerDate: now,
      isInsideGeofence: true,
    );
  }

  Reminder markInsideGeofence(bool value) {
    if (isInsideGeofence == value) {
      return this;
    }
    return copyWith(isInsideGeofence: value);
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      return int.tryParse('$value') ?? fallback;
    }

    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse('$value') ?? fallback;
    }

    DateTime? readDate(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final triggerLimitName = json['triggerLimit'] as String?;
    final triggerLimit = switch (triggerLimitName) {
      'oncePerDay' => TriggerLimit.daily,
      String name => TriggerLimit.values.firstWhere(
        (item) => item.name == name,
        orElse: () => TriggerLimit.always,
      ),
      _ => TriggerLimit.always,
    };
    final alertModeName = json['alertMode'] as String?;
    final alertMode = AlertMode.values.firstWhere(
      (item) => item.name == alertModeName,
      orElse: () => AlertMode.notification,
    );
    final lastTriggeredAt = readDate('lastTriggeredAt');
    final dailyTriggerDate =
        readDate('dailyTriggerDate') ??
        (triggerLimit == TriggerLimit.daily ? lastTriggeredAt : null);

    return Reminder(
      id: normalizeId(readInt('id', DateTime.now().millisecondsSinceEpoch)),
      title: json['title'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '未命名地点',
      latitude: readDouble('latitude', 31.2304),
      longitude: readDouble('longitude', 121.4737),
      radiusMeters: readInt('radiusMeters', 200),
      isEnabled: json['isEnabled'] as bool? ?? true,
      triggerLimit: triggerLimit,
      dailyTriggerLimit: readInt('dailyTriggerLimit', 1).clamp(1, 24).toInt(),
      scheduleLabel: json['scheduleLabel'] as String? ?? '全天生效',
      alertMode: alertMode,
      createdAt: readDate('createdAt') ?? DateTime.now(),
      lastTriggeredAt: lastTriggeredAt,
      lastTriggeredLabel: json['lastTriggeredLabel'] as String?,
      dailyTriggeredCount: readInt(
        'dailyTriggeredCount',
        dailyTriggerDate == null ? 0 : 1,
      ),
      dailyTriggerDate: dailyTriggerDate,
      isInsideGeofence: json['isInsideGeofence'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isEnabled': isEnabled,
      'triggerLimit': triggerLimit.name,
      'dailyTriggerLimit': dailyTriggerLimit,
      'scheduleLabel': scheduleLabel,
      'alertMode': alertMode.name,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
      'lastTriggeredLabel': lastTriggeredLabel,
      'dailyTriggeredCount': dailyTriggeredCount,
      'dailyTriggerDate': dailyTriggerDate?.toIso8601String(),
      'isInsideGeofence': isInsideGeofence,
    };
  }

  Reminder copyWith({
    int? id,
    String? title,
    String? locationName,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? isEnabled,
    TriggerLimit? triggerLimit,
    int? dailyTriggerLimit,
    String? scheduleLabel,
    AlertMode? alertMode,
    DateTime? createdAt,
    DateTime? lastTriggeredAt,
    String? lastTriggeredLabel,
    int? dailyTriggeredCount,
    DateTime? dailyTriggerDate,
    bool? isInsideGeofence,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isEnabled: isEnabled ?? this.isEnabled,
      triggerLimit: triggerLimit ?? this.triggerLimit,
      dailyTriggerLimit: dailyTriggerLimit ?? this.dailyTriggerLimit,
      scheduleLabel: scheduleLabel ?? this.scheduleLabel,
      alertMode: alertMode ?? this.alertMode,
      createdAt: createdAt ?? this.createdAt,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      lastTriggeredLabel: lastTriggeredLabel ?? this.lastTriggeredLabel,
      dailyTriggeredCount: dailyTriggeredCount ?? this.dailyTriggeredCount,
      dailyTriggerDate: dailyTriggerDate ?? this.dailyTriggerDate,
      isInsideGeofence: isInsideGeofence ?? this.isInsideGeofence,
    );
  }

  static List<Reminder> demoList() {
    final now = DateTime.now();
    return [
      Reminder(
        id: 1,
        title: '买布洛芬和创可贴',
        locationName: '康宁大药房',
        latitude: 31.2304,
        longitude: 121.4737,
        radiusMeters: 200,
        isEnabled: true,
        triggerLimit: TriggerLimit.always,
        dailyTriggerLimit: 1,
        scheduleLabel: '全天生效',
        alertMode: AlertMode.notification,
        createdAt: now.subtract(const Duration(hours: 2)),
        lastTriggeredAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      Reminder(
        id: 2,
        title: '鸡蛋、牛奶、洗衣液',
        locationName: '永辉超市',
        latitude: 31.224,
        longitude: 121.469,
        radiusMeters: 500,
        isEnabled: true,
        triggerLimit: TriggerLimit.daily,
        dailyTriggerLimit: 1,
        scheduleLabel: '18:00-21:00',
        alertMode: AlertMode.alarm,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      Reminder(
        id: 3,
        title: '取洗好的西装',
        locationName: '云杉干洗',
        latitude: 31.218,
        longitude: 121.481,
        radiusMeters: 100,
        isEnabled: false,
        triggerLimit: TriggerLimit.always,
        dailyTriggerLimit: 1,
        scheduleLabel: '工作日 09:00-19:00',
        alertMode: AlertMode.notification,
        createdAt: now.subtract(const Duration(days: 4)),
        lastTriggeredAt: now.subtract(const Duration(days: 23, hours: 5)),
      ),
    ];
  }

  static int normalizeId(int id) {
    final normalized = id % 0x7fffffff;
    return normalized == 0 ? 1 : normalized;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatTriggerTime(DateTime time) {
    final now = DateTime.now();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (_isSameDay(time, now)) {
      return '今天 $hour:$minute';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(time, yesterday)) {
      return '昨天 $hour:$minute';
    }
    return '${time.month}月${time.day}日 $hour:$minute';
  }

  static _ScheduleRange? _parseScheduleRange(String label) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})',
    ).firstMatch(label);
    if (match == null) {
      return null;
    }

    final startHour = int.tryParse(match.group(1)!);
    final startMinute = int.tryParse(match.group(2)!);
    final endHour = int.tryParse(match.group(3)!);
    final endMinute = int.tryParse(match.group(4)!);
    if (!_isValidTime(startHour, startMinute) ||
        !_isValidTime(endHour, endMinute)) {
      return null;
    }
    return _ScheduleRange(
      startHour: startHour!,
      startMinute: startMinute!,
      endHour: endHour!,
      endMinute: endMinute!,
    );
  }

  static bool _isValidTime(int? hour, int? minute) {
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }
}

class _ScheduleRange {
  const _ScheduleRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}
