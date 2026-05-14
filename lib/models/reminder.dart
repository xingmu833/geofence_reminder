enum TriggerLimit { always, oncePerDay }

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
    required this.scheduleLabel,
    required this.createdAt,
    this.lastTriggeredLabel,
  });

  final int id;
  final String title;
  final String locationName;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isEnabled;
  final TriggerLimit triggerLimit;
  final String scheduleLabel;
  final DateTime createdAt;
  final String? lastTriggeredLabel;

  String get radiusLabel {
    if (radiusMeters >= 1000) {
      final value = radiusMeters / 1000;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}km';
    }
    return '${radiusMeters}m';
  }

  String get triggerLimitLabel {
    return triggerLimit == TriggerLimit.always ? '每次进入' : '每天一次';
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

    final triggerLimitName = json['triggerLimit'] as String?;
    final triggerLimit = TriggerLimit.values.firstWhere(
      (item) => item.name == triggerLimitName,
      orElse: () => TriggerLimit.always,
    );

    return Reminder(
      id: readInt('id', DateTime.now().microsecondsSinceEpoch),
      title: json['title'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '未命名地点',
      latitude: readDouble('latitude', 31.2304),
      longitude: readDouble('longitude', 121.4737),
      radiusMeters: readInt('radiusMeters', 200),
      isEnabled: json['isEnabled'] as bool? ?? true,
      triggerLimit: triggerLimit,
      scheduleLabel: json['scheduleLabel'] as String? ?? '全天生效',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastTriggeredLabel: json['lastTriggeredLabel'] as String?,
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
      'scheduleLabel': scheduleLabel,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggeredLabel': lastTriggeredLabel,
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
    String? scheduleLabel,
    DateTime? createdAt,
    String? lastTriggeredLabel,
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
      scheduleLabel: scheduleLabel ?? this.scheduleLabel,
      createdAt: createdAt ?? this.createdAt,
      lastTriggeredLabel: lastTriggeredLabel ?? this.lastTriggeredLabel,
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
        scheduleLabel: '全天生效',
        createdAt: now.subtract(const Duration(hours: 2)),
        lastTriggeredLabel: '昨天 18:36',
      ),
      Reminder(
        id: 2,
        title: '鸡蛋、牛奶、洗衣液',
        locationName: '永辉超市',
        latitude: 31.224,
        longitude: 121.469,
        radiusMeters: 500,
        isEnabled: true,
        triggerLimit: TriggerLimit.oncePerDay,
        scheduleLabel: '18:00-21:00',
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
        scheduleLabel: '工作日 09:00-19:00',
        createdAt: now.subtract(const Duration(days: 4)),
        lastTriggeredLabel: '4月26日 12:10',
      ),
    ];
  }
}
