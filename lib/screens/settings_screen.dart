import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_settings_store.dart';
import '../services/geofence_service.dart';
import '../services/permission_service.dart';
import '../services/reminder_store.dart';
import '../widgets/app_feedback_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppPermissionService _permissionService = const AppPermissionService();
  final AppSettingsStore _settingsStore = const AppSettingsStore();
  final ReminderStore _reminderStore = const ReminderStore();
  final AppGeofenceService _geofenceService = const AppGeofenceService();
  AppPermissionSnapshot? _permissionSnapshot;
  AppSettingsSnapshot? _settings;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final permissionSnapshot = await _permissionService.loadStatuses();
    final settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionSnapshot = permissionSnapshot;
      _settings = settings;
    });
  }

  Future<void> _runPermissionAction(
    Future<AppPermissionSnapshot> Function() action,
  ) async {
    setState(() => _isBusy = true);
    final snapshot = await action();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionSnapshot = snapshot;
      _isBusy = false;
    });
  }

  Future<void> _saveSettings(AppSettingsSnapshot settings) async {
    await _settingsStore.save(settings);
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
  }

  Future<void> _exportRules() async {
    final json = await _reminderStore.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    final current = _settings ?? await _settingsStore.load();
    await _saveSettings(current.copyWith(exportedRulesJson: json));
    if (!mounted) {
      return;
    }
    await AppFeedbackDialog.show(
      context,
      title: '已导出',
      message: '提醒规则 JSON 已复制到剪贴板。',
      icon: Icons.file_upload_outlined,
    );
  }

  Future<void> _clearRules() async {
    final confirmed = await AppFeedbackDialog.confirm(
      context,
      title: '清空提醒规则',
      message: '确定清空所有提醒吗？这会同时移除已注册的地理围栏。',
      icon: Icons.delete_outline,
      cancelLabel: '取消',
      confirmLabel: '清空',
    );
    if (!confirmed) {
      return;
    }

    await _reminderStore.clearReminders();
    await _geofenceService.syncReminders(const []);
    if (!mounted) {
      return;
    }
    await AppFeedbackDialog.show(
      context,
      title: '已清空',
      message: '所有提醒规则已删除。',
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionSnapshot = _permissionSnapshot;
    final settings =
        _settings ??
        const AppSettingsSnapshot(
          vibrationEnabled: true,
          repeatReminderEnabled: false,
          exportedRulesJson: null,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (_isBusy) const LinearProgressIndicator(),
          if (_isBusy) const SizedBox(height: 14),
          _SettingsSection(
            title: '权限设置',
            children: [
              _ActionTile(
                icon: Icons.my_location_outlined,
                title: '定位与后台定位',
                subtitle: '用于创建围栏，并在 App 退出后继续判断是否到达地点',
                status: permissionSnapshot == null
                    ? '读取中'
                    : permissionSnapshot.locationReady &&
                          permissionSnapshot.backgroundReady
                    ? '已允许'
                    : '待授权',
                isGood:
                    permissionSnapshot?.locationReady == true &&
                    permissionSnapshot?.backgroundReady == true,
                actionLabel: '申请',
                onPressed: _isBusy
                    ? null
                    : () => _runPermissionAction(
                        _permissionService.requestLocationPermissions,
                      ),
              ),
              _ActionTile(
                icon: Icons.notifications_active_outlined,
                title: '通知权限',
                subtitle: '到达地点后弹出本地通知',
                status: permissionSnapshot == null
                    ? '读取中'
                    : permissionSnapshot.notificationReady
                    ? '已允许'
                    : '待授权',
                isGood: permissionSnapshot?.notificationReady == true,
                actionLabel: '申请',
                onPressed: _isBusy
                    ? null
                    : () => _runPermissionAction(
                        _permissionService.requestNotificationPermission,
                      ),
              ),
              _ActionTile(
                icon: Icons.battery_saver_outlined,
                title: '忽略电池优化',
                subtitle: '允许后台围栏服务更稳定地运行',
                status: permissionSnapshot == null
                    ? '读取中'
                    : permissionSnapshot.batteryReady
                    ? '已允许'
                    : '待配置',
                isGood: permissionSnapshot?.batteryReady == true,
                actionLabel: '申请',
                onPressed: _isBusy
                    ? null
                    : () => _runPermissionAction(
                        _permissionService
                            .requestBatteryOptimizationPermission,
                      ),
              ),
              _ActionTile(
                icon: Icons.settings_applications_outlined,
                title: '系统应用设置',
                subtitle: '手动开启后台定位、自启动、通知和省电无限制',
                status: '手动',
                isGood: false,
                actionLabel: '打开',
                onPressed: _isBusy
                    ? null
                    : () => _permissionService.openSystemSettings(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: '提醒偏好',
            children: [
              _SwitchTile(
                icon: Icons.vibration_outlined,
                title: '通知震动',
                subtitle: '触发提醒时同步震动',
                value: settings.vibrationEnabled,
                onChanged: (value) => _saveSettings(
                  settings.copyWith(vibrationEnabled: value),
                ),
              ),
              _SwitchTile(
                icon: Icons.repeat_on_outlined,
                title: '重复提醒',
                subtitle: '未处理提醒时保留重复提醒偏好',
                value: settings.repeatReminderEnabled,
                onChanged: (value) => _saveSettings(
                  settings.copyWith(repeatReminderEnabled: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: '数据',
            children: [
              _ActionTile(
                icon: Icons.file_upload_outlined,
                title: '导出提醒规则',
                subtitle: settings.exportedRulesJson == null
                    ? '生成本地 JSON 备份并复制到剪贴板'
                    : '已生成过备份，可再次复制最新规则',
                status: settings.exportedRulesJson == null ? '未导出' : '已导出',
                isGood: settings.exportedRulesJson != null,
                actionLabel: '复制',
                onPressed: _exportRules,
              ),
              _ActionTile(
                icon: Icons.delete_sweep_outlined,
                title: '清空提醒规则',
                subtitle: '删除本机保存的提醒，并同步移除地理围栏',
                status: '危险操作',
                isGood: false,
                actionLabel: '清空',
                onPressed: _clearRules,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isGood,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool isGood;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _SettingsIcon(icon: icon, color: _statusColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          _StatusPill(status: status, isGood: isGood),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Color get _statusColor =>
      isGood ? const Color(0xFF2563EB) : const Color(0xFFEA8A12);
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    return SwitchListTile(
      secondary: _SettingsIcon(icon: icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.isGood});

  final String status;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final color = isGood ? const Color(0xFF2563EB) : const Color(0xFFEA8A12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
