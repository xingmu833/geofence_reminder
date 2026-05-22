import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reminder.dart';
import '../services/app_settings_store.dart';
import '../services/geofence_service.dart';
import '../services/notification_service.dart';
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
  DeviceSupportInfo? _deviceSupportInfo;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final permissionSnapshot = await _permissionService.loadStatuses();
    final settings = await _settingsStore.load();
    final deviceSupportInfo = await _permissionService.loadDeviceSupportInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionSnapshot = permissionSnapshot;
      _settings = settings;
      _deviceSupportInfo = deviceSupportInfo;
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

  Future<void> _sendTestNotification(AlertMode alertMode) async {
    try {
      await NotificationService.showGeofenceReminder(
        id: alertMode == AlertMode.alarm ? 900002 : 900001,
        title: alertMode == AlertMode.alarm ? '强提醒测试' : '通知提醒测试',
        body: '如果你看到这条提醒，说明通知链路正常。',
        alertMode: alertMode,
      );
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

  Future<void> _openVendorGuide(DeviceSupportInfo info) async {
    final confirmed = await AppFeedbackDialog.confirm(
      context,
      title: '${info.vendorName}权限建议',
      message:
          '为了让后台定位和强提醒更稳定，请在系统设置中确认：${info.subtitle}。不同系统版本入口名称可能略有差异。',
      icon: Icons.admin_panel_settings_outlined,
      cancelLabel: '稍后',
      confirmLabel: '去设置',
    );
    if (!confirmed) {
      return;
    }

    final opened = await _permissionService.openVendorPowerSettings();
    if (!mounted || opened) {
      return;
    }
    await AppFeedbackDialog.show(
      context,
      title: '无法直达设置页',
      message: '系统拦截了厂商权限入口，请从应用信息页手动检查后台运行、省电策略、自启动和锁屏通知。',
      icon: Icons.settings_outlined,
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
    final deviceSupportInfo = _deviceSupportInfo;

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
              if (deviceSupportInfo != null &&
                  deviceSupportInfo.hasVendorGuide)
                _ActionTile(
                  icon: Icons.security_outlined,
                  title: '${deviceSupportInfo.vendorName}后台策略',
                  subtitle: deviceSupportInfo.subtitle,
                  status: '建议配置',
                  isGood: false,
                  actionLabel: '查看',
                  onPressed: _isBusy
                      ? null
                      : () => _openVendorGuide(deviceSupportInfo),
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
              _ActionTile(
                icon: Icons.music_note_outlined,
                title: '铃声与通知渠道',
                subtitle: '强提醒/通知的铃声、震动等由系统通知渠道管理',
                status: '系统设置',
                isGood: true,
                actionLabel: '打开',
                onPressed: () => _permissionService.openSystemSettings(),
              ),
              _ActionTile(
                icon: Icons.notifications_none_outlined,
                title: '测试通知提醒',
                subtitle: '不经过定位，直接发送一条普通通知',
                status: '测试',
                isGood: true,
                actionLabel: '发送',
                onPressed: () => _sendTestNotification(AlertMode.notification),
              ),
              _ActionTile(
                icon: Icons.alarm_outlined,
                title: '测试强提醒',
                subtitle: '不经过定位，直接发送一条高优先级提醒',
                status: '测试',
                isGood: true,
                actionLabel: '发送',
                onPressed: () => _sendTestNotification(AlertMode.alarm),
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
