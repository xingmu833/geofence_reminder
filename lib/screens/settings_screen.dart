import 'package:flutter/material.dart';

import '../services/permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppPermissionService _permissionService = const AppPermissionService();
  AppPermissionSnapshot? _snapshot;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final snapshot = await _permissionService.loadStatuses();
    if (!mounted) {
      return;
    }
    setState(() => _snapshot = snapshot);
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
      _snapshot = snapshot;
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (_isBusy) const LinearProgressIndicator(),
          if (_isBusy) const SizedBox(height: 14),
          _SettingsSection(
            title: '真机调试权限',
            children: [
              _ActionTile(
                icon: Icons.my_location_outlined,
                title: '定位与后台定位',
                subtitle: '用于创建围栏，并在 App 退出后继续判断是否到达地点',
                status: snapshot == null
                    ? '读取中'
                    : snapshot.locationReady && snapshot.backgroundReady
                    ? '已允许'
                    : '待授权',
                isGood:
                    snapshot?.locationReady == true &&
                    snapshot?.backgroundReady == true,
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
                status: snapshot == null
                    ? '读取中'
                    : snapshot.notificationReady
                    ? '已允许'
                    : '待授权',
                isGood: snapshot?.notificationReady == true,
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
                subtitle: '红米 K50 还需要手动允许自启动，并把省电策略设为无限制',
                status: snapshot == null
                    ? '读取中'
                    : snapshot.batteryReady
                    ? '已允许'
                    : '待配置',
                isGood: snapshot?.batteryReady == true,
                actionLabel: '申请',
                onPressed: _isBusy
                    ? null
                    : () => _runPermissionAction(
                        _permissionService.requestBatteryOptimizationPermission,
                      ),
              ),
              _ActionTile(
                icon: Icons.settings_applications_outlined,
                title: '系统应用设置',
                subtitle: '用于手动开启后台定位、自启动、通知和省电无限制',
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
          const _SettingsSection(
            title: '提醒偏好',
            children: [
              _StaticTile(
                icon: Icons.vibration_outlined,
                title: '通知震动',
                subtitle: '触发提醒时同步震动',
                status: '已开启',
                isGood: true,
              ),
              _StaticTile(
                icon: Icons.repeat_on_outlined,
                title: '重复提醒',
                subtitle: '未处理时 15 分钟后再次提醒',
                status: '关闭',
                isGood: false,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SettingsSection(
            title: '数据',
            children: [
              _StaticTile(
                icon: Icons.file_upload_outlined,
                title: '导出提醒规则',
                subtitle: '生成本地 JSON 备份',
                status: '未启用',
                isGood: false,
              ),
              _StaticTile(
                icon: Icons.privacy_tip_outlined,
                title: '隐私说明',
                subtitle: '位置与提醒数据仅保存在本机',
                status: '本地',
                isGood: true,
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
      leading: Icon(icon, color: _statusColor),
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
      isGood ? const Color(0xFF28785E) : const Color(0xFFC27A2C);
}

class _StaticTile extends StatelessWidget {
  const _StaticTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isGood,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final color = isGood ? const Color(0xFF28785E) : const Color(0xFFC27A2C);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _StatusPill(status: status, isGood: isGood),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.isGood});

  final String status;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final color = isGood ? const Color(0xFF28785E) : const Color(0xFFC27A2C);

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
