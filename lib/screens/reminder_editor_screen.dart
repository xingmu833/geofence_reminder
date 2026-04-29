import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../widgets/map_picker.dart';
import '../widgets/radius_selector.dart';

class ReminderEditorScreen extends StatefulWidget {
  const ReminderEditorScreen({super.key, this.reminder});

  final Reminder? reminder;

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late int _radiusMeters;
  late bool _isEnabled;
  late bool _allDay;
  late TriggerLimit _triggerLimit;
  bool _hasPin = true;

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
    _allDay =
        reminder?.scheduleLabel == null || reminder!.scheduleLabel == '全天生效';
    _triggerLimit = reminder?.triggerLimit ?? TriggerLimit.always;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasPin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在地图上选择提醒位置')));
      return;
    }

    final now = DateTime.now();
    final old = widget.reminder;
    Navigator.of(context).pop(
      Reminder(
        id: old?.id ?? now.microsecondsSinceEpoch,
        title: _titleController.text.trim(),
        locationName: _locationController.text.trim(),
        latitude: old?.latitude ?? 31.2304,
        longitude: old?.longitude ?? 121.4737,
        radiusMeters: _radiusMeters,
        isEnabled: _isEnabled,
        triggerLimit: _triggerLimit,
        scheduleLabel: _allDay ? '全天生效' : '18:00-21:00',
        createdAt: old?.createdAt ?? now,
        lastTriggeredLabel: old?.lastTriggeredLabel,
      ),
    );
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
              onPinChanged: (value) => setState(() => _hasPin = value),
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
              decoration: const InputDecoration(
                labelText: '地点名称',
                hintText: '例如：康宁大药房',
                prefixIcon: Icon(Icons.place_outlined),
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
                  subtitle: Text(_allDay ? '全天都可以触发' : '仅 18:00-21:00 生效'),
                  value: _allDay,
                  onChanged: (value) => setState(() => _allDay = value),
                ),
              ],
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
                  value: TriggerLimit.oncePerDay,
                  icon: Icon(Icons.today_outlined),
                  label: Text('每天一次'),
                ),
              ],
              selected: {_triggerLimit},
              onSelectionChanged: (values) {
                setState(() => _triggerLimit = values.first);
              },
            ),
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
