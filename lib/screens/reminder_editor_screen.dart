import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/baidu_geocoding_service.dart';
import '../widgets/app_feedback_dialog.dart';
import '../widgets/map_picker.dart';
import '../widgets/radius_selector.dart';

class ReminderEditorScreen extends StatefulWidget {
  const ReminderEditorScreen({super.key, this.reminder});

  final Reminder? reminder;

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  final BaiduGeocodingService _geocodingService = const BaiduGeocodingService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late int _radiusMeters;
  late bool _isEnabled;
  late bool _allDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TriggerLimit _triggerLimit;
  late int _dailyTriggerLimit;
  late AlertMode _alertMode;
  late double _latitude;
  late double _longitude;
  bool _hasPin = true;
  bool _isSearchingLocation = false;

  bool get _isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _titleController = TextEditingController(text: reminder?.title ?? '');
    _locationController = TextEditingController(
      text: reminder?.locationName ?? '当前位置附近',
    );
    _radiusMeters = reminder?.radiusMeters ?? 200;
    _isEnabled = reminder?.isEnabled ?? true;
    _latitude = reminder?.latitude ?? 31.2304;
    _longitude = reminder?.longitude ?? 121.4737;
    final scheduleRange = _parseScheduleRange(reminder?.scheduleLabel);
    _allDay = reminder == null || reminder.scheduleLabel == '全天生效';
    _startTime = scheduleRange?.start ?? const TimeOfDay(hour: 18, minute: 0);
    _endTime = scheduleRange?.end ?? const TimeOfDay(hour: 21, minute: 0);
    _triggerLimit = reminder?.triggerLimit ?? TriggerLimit.always;
    _dailyTriggerLimit = reminder?.dailyTriggerLimit ?? 1;
    _alertMode = reminder?.alertMode ?? AlertMode.notification;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasPin) {
      await AppFeedbackDialog.show(
        context,
        title: '还没有选点',
        message: '请先在地图上选择提醒位置，再保存提醒。',
        icon: Icons.add_location_alt_outlined,
      );
      return;
    }

    final now = DateTime.now();
    final old = widget.reminder;
    Navigator.of(context).pop(
      Reminder(
        id: old?.id ?? _createReminderId(now),
        title: _titleController.text.trim(),
        locationName: _locationController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        radiusMeters: _radiusMeters,
        isEnabled: _isEnabled,
        triggerLimit: _triggerLimit,
        dailyTriggerLimit: _dailyTriggerLimit,
        alertMode: _alertMode,
        scheduleLabel: _allDay
            ? '全天生效'
            : '${_formatTime(_startTime)}-${_formatTime(_endTime)}',
        createdAt: old?.createdAt ?? now,
        lastTriggeredAt: old?.lastTriggeredAt,
        lastTriggeredLabel: old?.lastTriggeredLabel,
        dailyTriggeredCount: old?.dailyTriggeredCount ?? 0,
        dailyTriggerDate: old?.dailyTriggerDate,
        isInsideGeofence: old?.isInsideGeofence ?? false,
      ),
    );
  }

  Future<void> _searchLocationByName() async {
    final query = _locationController.text.trim();
    if (query.isEmpty) {
      await AppFeedbackDialog.show(
        context,
        title: '请输入地点',
        message: '请先输入地点名称，再搜索附近真实地点。',
        icon: Icons.search,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSearchingLocation = true);
    try {
      final searchRadius = (_radiusMeters * 20).clamp(3000, 20000).toInt();
      final results = await _geocodingService.searchNearbyPlaces(
        keyword: query,
        centerLatitude: _latitude,
        centerLongitude: _longitude,
        radiusMeters: searchRadius,
      );
      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        await AppFeedbackDialog.show(
          context,
          title: '没有找到地点',
          message: '附近没有找到匹配地点，请移动地图到目标区域，或换一个更具体的关键词。',
          icon: Icons.manage_search,
        );
        return;
      }

      final selected = await _showPlacePicker(results);
      if (!mounted || selected == null) {
        return;
      }

      setState(() {
        _locationController.text = selected.name;
        _latitude = selected.latitude;
        _longitude = selected.longitude;
        _hasPin = true;
      });
      await AppFeedbackDialog.show(
        context,
        title: '已定位',
        message: '已将地图选点移动到“${selected.name}”。',
        icon: Icons.place_outlined,
      );
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  Future<BaiduPlaceResult?> _showPlacePicker(List<BaiduPlaceResult> places) {
    return showModalBottomSheet<BaiduPlaceResult>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: places.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final place = places[index];
              final subtitle = place.subtitle;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(place.name),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: place.distanceMeters == null
                    ? null
                    : Text('${place.distanceMeters}m'),
                onTap: () => Navigator.of(context).pop(place),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  ({TimeOfDay start, TimeOfDay end})? _parseScheduleRange(String? label) {
    if (label == null) {
      return null;
    }

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

    return (
      start: TimeOfDay(hour: startHour!, minute: startMinute!),
      end: TimeOfDay(hour: endHour!, minute: endMinute!),
    );
  }

  bool _isValidTime(int? hour, int? minute) {
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _createReminderId(DateTime time) {
    return Reminder.normalizeId(time.millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑提醒' : '新增提醒'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            MapPicker(
              radiusMeters: _radiusMeters,
              hasPin: _hasPin,
              latitude: _latitude,
              longitude: _longitude,
              onPinChanged: (value) => setState(() => _hasPin = value),
              onLocationChanged: (latitude, longitude) {
                setState(() {
                  _latitude = latitude;
                  _longitude = longitude;
                });
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '提醒内容',
                hintText: '例如：买布洛芬',
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入提醒内容';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _locationController,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _searchLocationByName(),
              decoration: InputDecoration(
                labelText: '地点名称',
                hintText: '例如：康宁大药房',
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: IconButton(
                  tooltip: '搜索附近地点',
                  onPressed: _isSearchingLocation
                      ? null
                      : _searchLocationByName,
                  icon: _isSearchingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入地点名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            RadiusSelector(
              value: _radiusMeters,
              onChanged: (value) => setState(() => _radiusMeters = value),
            ),
            const SizedBox(height: 18),
            _SettingPanel(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用此提醒'),
                  subtitle: const Text('关闭后将暂停地理围栏监听'),
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('全天生效'),
                  subtitle: Text(
                    _allDay
                        ? '全天都可以触发'
                        : '仅在 ${_formatTime(_startTime)}-${_formatTime(_endTime)} 生效',
                  ),
                  value: _allDay,
                  onChanged: (value) => setState(() => _allDay = value),
                ),
                if (!_allDay) ...[
                  const Divider(height: 1),
                  _TimeRangePicker(
                    startLabel: _formatTime(_startTime),
                    endLabel: _formatTime(_endTime),
                    onStartTap: () => _pickTime(isStart: true),
                    onEndTap: () => _pickTime(isStart: false),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _SectionLabel(
              title: '提醒方式',
              subtitle: '强提醒会使用高优先级通知渠道，铃声可在系统通知设置中调整。',
            ),
            const SizedBox(height: 10),
            SegmentedButton<AlertMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AlertMode.notification,
                  icon: Icon(Icons.notifications_none_outlined),
                  label: Text('通知'),
                ),
                ButtonSegment(
                  value: AlertMode.alarm,
                  icon: Icon(Icons.alarm_outlined),
                  label: Text('强提醒'),
                ),
              ],
              selected: {_alertMode},
              onSelectionChanged: (values) {
                setState(() => _alertMode = values.first);
              },
            ),
            const SizedBox(height: 18),
            SegmentedButton<TriggerLimit>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TriggerLimit.always,
                  icon: Icon(Icons.repeat),
                  label: Text('每次进入'),
                ),
                ButtonSegment(
                  value: TriggerLimit.once,
                  icon: Icon(Icons.looks_one_outlined),
                  label: Text('仅此一次'),
                ),
                ButtonSegment(
                  value: TriggerLimit.daily,
                  icon: Icon(Icons.today_outlined),
                  label: Text('每天多次'),
                ),
              ],
              selected: {_triggerLimit},
              onSelectionChanged: (values) {
                setState(() => _triggerLimit = values.first);
              },
            ),
            if (_triggerLimit == TriggerLimit.daily) ...[
              const SizedBox(height: 12),
              _DailyTriggerLimitPicker(
                value: _dailyTriggerLimit,
                onChanged: (value) => setState(() => _dailyTriggerLimit = value),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? '保存修改' : '创建提醒'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF60708F))),
      ],
    );
  }
}

class _DailyTriggerLimitPicker extends StatelessWidget {
  const _DailyTriggerLimitPicker({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E3F8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.repeat_on_outlined, color: Color(0xFF60708F)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '每天触发次数',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.outlined(
            tooltip: '减少次数',
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value次',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.outlined(
            tooltip: '增加次数',
            onPressed: value >= 24 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _TimeRangePicker extends StatelessWidget {
  const _TimeRangePicker({
    required this.startLabel,
    required this.endLabel,
    required this.onStartTap,
    required this.onEndTap,
  });

  final String startLabel;
  final String endLabel;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _TimeButton(
              label: '开始时间',
              value: startLabel,
              onTap: onStartTap,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward, size: 18),
          ),
          Expanded(
            child: _TimeButton(label: '结束时间', value: endLabel, onTap: onEndTap),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF60708F)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SettingPanel extends StatelessWidget {
  const _SettingPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}
