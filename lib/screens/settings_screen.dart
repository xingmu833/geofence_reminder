import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: const [
          _SettingsSection(
            title: '权限状态',
            children: [
              _SettingsTile(
                icon: Icons.my_location_outlined,
                title: '定位权限',
                subtitle: '用于判断是否进入提醒范围',
                status: '已允许',
                isGood: true,
              ),
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: '通知权限',
                subtitle: '到达地点后弹出本地通知',
                status: '已允许',
                isGood: true,
              ),
              _SettingsTile(
                icon: Icons.battery_saver_outlined,
                title: '后台与电池优化',
                subtitle: '建议加入电池优化白名单',
                status: '待配置',
                isGood: false,
              ),
            ],
          ),
          SizedBox(height: 18),
          _SettingsSection(
            title: '提醒偏好',
            children: [
              _SettingsTile(
                icon: Icons.vibration_outlined,
                title: '通知震动',
                subtitle: '触发提醒时同步震动',
                status: '已开启',
                isGood: true,
              ),
              _SettingsTile(
                icon: Icons.repeat_on_outlined,
                title: '重复提醒',
                subtitle: '未处理时 15 分钟后再次提醒',
                status: '关闭',
                isGood: false,
              ),
            ],
          ),
          SizedBox(height: 18),
          _SettingsSection(
            title: '数据',
            children: [
              _SettingsTile(
                icon: Icons.file_upload_outlined,
                title: '导出提醒规则',
                subtitle: '生成本地 JSON 备份',
                status: '未启用',
                isGood: false,
              ),
              _SettingsTile(
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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
      trailing: Container(
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
      ),
    );
  }
}
