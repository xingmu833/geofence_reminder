import 'dart:async';

import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/geofence_service.dart';
import '../services/reminder_store.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final ReminderStore _store = const ReminderStore();
  final AppGeofenceService _geofenceService = const AppGeofenceService();
  List<Reminder> _trash = const [];
  final Set<int> _selectedIds = {};
  bool _isLoading = true;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final trash = await _store.loadTrashReminders();
    if (!mounted) {
      return;
    }
    setState(() {
      _trash = trash;
      _selectedIds.clear();
      _isLoading = false;
    });
  }

  Future<void> _restoreIds(Iterable<int> ids) async {
    final reminders = await _store.restoreFromTrash(ids);
    await _loadTrash();
    _syncRemindersSilently(reminders);
  }

  Future<void> _deleteIds(Iterable<int> ids) async {
    await _store.deleteTrashReminders(ids);
    await _loadTrash();
  }

  Future<void> _restoreAll() async {
    final reminders = await _store.restoreAllTrashReminders();
    await _loadTrash();
    _syncRemindersSilently(reminders);
  }

  Future<void> _clearTrash() async {
    await _store.clearTrashReminders();
    await _loadTrash();
  }

  void _toggleSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _syncRemindersSilently(List<Reminder> reminders) {
    unawaited(_geofenceService.syncReminders(reminders).catchError((_) {}));
  }

  void _openDetail(Reminder reminder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrashReminderDetailScreen(reminder: reminder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelecting ? '已选择 ${_selectedIds.length} 项' : '回收站'),
        actions: [
          if (_isSelecting) ...[
            IconButton(
              tooltip: '还原所选',
              onPressed: () => _restoreIds(_selectedIds),
              icon: const Icon(Icons.restore_outlined),
            ),
            IconButton(
              tooltip: '删除所选',
              onPressed: () => _deleteIds(_selectedIds),
              icon: const Icon(Icons.delete_outline),
            ),
          ] else if (_trash.isNotEmpty) ...[
            IconButton(
              tooltip: '全部还原',
              onPressed: _restoreAll,
              icon: const Icon(Icons.settings_backup_restore_outlined),
            ),
            IconButton(
              tooltip: '清空回收站',
              onPressed: _clearTrash,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trash.isEmpty
          ? const _EmptyTrash()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _trash.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final reminder = _trash[index];
                return _TrashReminderTile(
                  reminder: reminder,
                  selected: _selectedIds.contains(reminder.id),
                  selecting: _isSelecting,
                  onTap: () => _isSelecting
                      ? _toggleSelected(reminder.id)
                      : _openDetail(reminder),
                  onLongPress: () => _toggleSelected(reminder.id),
                  onSelected: () => _toggleSelected(reminder.id),
                  onRestore: () => _restoreIds([reminder.id]),
                );
              },
            ),
    );
  }
}

class _TrashReminderTile extends StatelessWidget {
  const _TrashReminderTile({
    required this.reminder,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onSelected,
    required this.onRestore,
  });

  final Reminder reminder;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSelected;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
          child: Row(
            children: [
              if (selecting) ...[
                Checkbox(value: selected, onChanged: (_) => onSelected()),
                const SizedBox(width: 4),
              ],
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reminder.alertMode == AlertMode.alarm
                      ? Icons.alarm_outlined
                      : Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reminder.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF60708F)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${reminder.radiusLabel} · ${reminder.scheduleLabel} · ${reminder.triggerLimitLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF60708F),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '还原',
                onPressed: onRestore,
                icon: const Icon(Icons.restore_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              '回收站为空',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '删除的事件会暂存在这里，最多保留 50 条。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF60708F)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashReminderDetailScreen extends StatelessWidget {
  const _TrashReminderDetailScreen({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('事件详情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _DetailItem(label: '提醒内容', value: reminder.title),
          _DetailItem(label: '地点名称', value: reminder.locationName),
          _DetailItem(label: '提醒半径', value: reminder.radiusLabel),
          _DetailItem(label: '生效时间', value: reminder.scheduleLabel),
          _DetailItem(label: '提醒方式', value: reminder.alertModeLabel),
          _DetailItem(label: '提示次数', value: reminder.triggerLimitLabel),
          _DetailItem(
            label: '坐标',
            value:
                '${reminder.latitude.toStringAsFixed(6)}, ${reminder.longitude.toStringAsFixed(6)}',
          ),
          if (reminder.displayLastTriggeredLabel != null)
            _DetailItem(
              label: '上次触发',
              value: reminder.displayLastTriggeredLabel!,
            ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF60708F))),
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
