import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/geofence_service.dart';
import '../services/native_geofence_bridge.dart';
import '../services/notification_service.dart';
import '../services/reminder_store.dart';
import '../widgets/app_feedback_dialog.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final ReminderStore _store = const ReminderStore();
  final AppGeofenceService _geofenceService = const AppGeofenceService();
  final NativeGeofenceBridge _nativeBridge = const NativeGeofenceBridge();
  List<Reminder> _reminders = const [];
  bool _isLoading = true;
  int? _testingId;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await _store.loadReminders();
    if (!mounted) {
      return;
    }
    setState(() {
      _reminders = reminders;
      _isLoading = false;
    });
  }

  Future<void> _simulateArrival(Reminder reminder) async {
    setState(() => _testingId = reminder.id);
    try {
      final reminders = await _store.loadReminders();
      final index = reminders.indexWhere((item) => item.id == reminder.id);
      if (index == -1) {
        await AppFeedbackDialog.show(
          context,
          title: '未找到事件',
          message: '请回到首页刷新事件列表后再试。',
          icon: Icons.warning_amber_outlined,
        );
        return;
      }

      final reset = [...reminders];
      reset[index] = reset[index].markInsideGeofence(false);
      await _store.saveReminders(reset);

      final triggeredCount =
          await _geofenceService.triggerMatchingStoredRemindersAt(
        latitude: reset[index].latitude,
        longitude: reset[index].longitude,
        useCooldown: false,
      );

      await _loadReminders();
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: triggeredCount > 0 ? '测试提醒已触发' : '测试未触发',
        message: triggeredCount > 0
            ? '通知链路已走通。可以回到系统通知栏查看提醒。'
            : '事件可能处于暂停、时间段外、仅此一次已触发或今日次数已满。',
        icon: triggeredCount > 0
            ? Icons.notifications_active_outlined
            : Icons.info_outline,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '测试失败',
        message: '请确认通知权限已开启，然后重试。',
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _testingId = null);
      }
    }
  }

  Future<void> _sendTestNotification(AlertMode alertMode) async {
    try {
      if (alertMode == AlertMode.alarm) {
        await _nativeBridge.showTestAlarm();
      } else {
        await NotificationService.showGeofenceReminder(
          id: 900001,
          title: '通知提醒测试',
          body: '如果你看到这条提醒，说明通知链路正常。',
          alertMode: alertMode,
        );
      }
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '测试已发送',
        message: '如果没有看到系统提醒，请检查系统通知权限、通知渠道和勿扰模式。',
        icon: Icons.notifications_active_outlined,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '测试失败',
        message: '$error',
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _syncGeofences() async {
    try {
      await _geofenceService.syncReminders(_reminders);
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '已同步',
        message: '已重新注册启用中的位置提醒。',
        icon: Icons.check_circle_outline,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '同步失败',
        message: '请确认定位权限已开启。',
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadReminders,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Text(
                      '测试',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '这里的操作只用于验证提醒链路，不需要真实移动。',
                      style: TextStyle(color: Color(0xFF60708F)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _syncGeofences,
                      icon: const Icon(Icons.sync),
                      label: const Text('重新同步位置提醒'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendTestNotification(
                              AlertMode.notification,
                            ),
                            icon: const Icon(Icons.notifications_none_outlined),
                            label: const Text('测试通知'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _sendTestNotification(AlertMode.alarm),
                            icon: const Icon(Icons.alarm_outlined),
                            label: const Text('测试强提醒'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_reminders.isEmpty)
                      const _EmptyTestState()
                    else
                      ..._reminders.map(
                        (reminder) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReminderTestTile(
                            reminder: reminder,
                            isTesting: _testingId == reminder.id,
                            onSimulateArrival: () =>
                                _simulateArrival(reminder),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReminderTestTile extends StatelessWidget {
  const _ReminderTestTile({
    required this.reminder,
    required this.isTesting,
    required this.onSimulateArrival,
  });

  final Reminder reminder;
  final bool isTesting;
  final VoidCallback onSimulateArrival;

  @override
  Widget build(BuildContext context) {
    final status = reminder.isEnabled ? '启用' : '暂停';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reminder.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${reminder.locationName} · ${reminder.radiusLabel} · ${reminder.triggerLimitLabel}',
              style: const TextStyle(color: Color(0xFF60708F)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isTesting ? null : onSimulateArrival,
              icon: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report_outlined),
              label: const Text('模拟到达目标地点'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTestState extends StatelessWidget {
  const _EmptyTestState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          '暂无事件可测试',
          style: TextStyle(color: Color(0xFF60708F)),
        ),
      ),
    );
  }
}
