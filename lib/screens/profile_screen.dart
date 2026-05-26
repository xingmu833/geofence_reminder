import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/reminder_store.dart';
import '../services/user_profile_store.dart';
import 'alarm_sound_screen.dart';
import 'personal_info_screen.dart';
import 'recycle_bin_screen.dart';
import 'reminder_page_diy_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onProfileChanged});

  final VoidCallback? onProfileChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileStore _profileStore = const UserProfileStore();
  final ReminderStore _reminderStore = const ReminderStore();
  UserProfile? _profile;
  List<Reminder> _reminders = const [];

  static const _avatars = [
    _AvatarOption(Icons.explore_outlined, Color(0xFF2563EB), Color(0xFFEAF1FF)),
    _AvatarOption(Icons.near_me_outlined, Color(0xFF0F766E), Color(0xFFE8F7F2)),
    _AvatarOption(Icons.bolt_outlined, Color(0xFFB45309), Color(0xFFFFF4DE)),
    _AvatarOption(Icons.nights_stay_outlined, Color(0xFF7C3AED), Color(0xFFF0E9FF)),
    _AvatarOption(Icons.favorite_outline, Color(0xFFE11D48), Color(0xFFFFE8EF)),
    _AvatarOption(Icons.auto_awesome_outlined, Color(0xFF0891B2), Color(0xFFE6F8FC)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileStore.load();
    List<Reminder> reminders;
    try {
      reminders = await _reminderStore.loadReminders();
    } catch (_) {
      reminders = const [];
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _reminders = reminders;
    });
  }

  Future<void> _openPersonalInfo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
    );
    await _load();
    widget.onProfileChanged?.call();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _openAlarmSound() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlarmSoundScreen()),
    );
  }

  Future<void> _openReminderPageDiy() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReminderPageDiyScreen()),
    );
  }

  Future<void> _openRecycleBin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecycleBinScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final isLoggedIn = profile?.isLoggedIn == true;
    final name = isLoggedIn ? profile!.displayName : '点击登录';
    final identifier = isLoggedIn
        ? profile!.identifier
        : '登录或注册后管理个人资料';
    final avatar =
        _avatars[(profile?.avatarIndex ?? 0).clamp(0, _avatars.length - 1).toInt()];
    final totalCount = _reminders.length;
    final activeCount = _reminders
        .where(
          (item) => item.isEnabled &&
              !(item.triggerLimit == TriggerLimit.once &&
                  item.lastTriggeredAt != null),
        )
        .length;
    final pausedCount = totalCount - activeCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _ProfileBackdrop(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
              children: [
                _ProfileHeader(
                  name: name,
                  subtitle: identifier,
                  avatar: avatar,
                  onTap: _openPersonalInfo,
                ),
                const SizedBox(height: 18),
                _StatsGrid(
                  activeCount: activeCount,
                  pausedCount: pausedCount,
                  totalCount: totalCount,
                ),
                const SizedBox(height: 18),
                _MenuPanel(
                  children: [
                    _ProfileItem(
                      icon: Icons.person_outline,
                      title: '个人信息',
                      subtitle: '头像、昵称、账号和密码',
                      onTap: _openPersonalInfo,
                    ),
                    _ProfileItem(
                      icon: Icons.settings_outlined,
                      title: '设置',
                      subtitle: '权限、提醒偏好和数据管理',
                      onTap: _openSettings,
                    ),
                    _ProfileItem(
                      icon: Icons.music_note_outlined,
                      title: '闹钟铃声',
                      subtitle: '选择内置铃声或本地音频',
                      onTap: _openAlarmSound,
                    ),
                    _ProfileItem(
                      icon: Icons.palette_outlined,
                      title: '提醒页面DIY',
                      subtitle: '上传并预览强提醒页面的自定义图片',
                      onTap: _openReminderPageDiy,
                    ),
                    _ProfileItem(
                      icon: Icons.delete_outline,
                      title: '回收站',
                      subtitle: '查看、还原或永久删除事件',
                      onTap: _openRecycleBin,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final _AvatarOption avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x302563EB),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
            BoxShadow(
              color: Color(0x1810B981),
              blurRadius: 18,
              offset: Offset(-8, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 29,
                backgroundColor: avatar.background,
                child: Icon(avatar.icon, color: avatar.color, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFEAF1FF)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.activeCount,
    required this.pausedCount,
    required this.totalCount,
  });

  final int activeCount;
  final int pausedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: '生效中',
            value: activeCount,
            icon: Icons.radar_outlined,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: '暂停',
            value: pausedCount,
            icon: Icons.pause_circle_outline,
            color: const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: '全部',
            value: totalCount,
            icon: Icons.list_alt_outlined,
            color: const Color(0xFF0F766E),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142563EB),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10203F),
                    height: 1,
                    fontSize: 27,
                  ),
            ),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF60708F),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142563EB),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 70),
          ],
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEAF1FF), Color(0xFFF2FBF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Color(0x102563EB),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFEFF8F5), Color(0xFFFFFBF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 86,
              right: -44,
              child: _Plane(
                width: 180,
                height: 96,
                color: Color(0x2E38BDF8),
              ),
            ),
            Positioned(
              top: 282,
              left: -56,
              child: _Plane(
                width: 190,
                height: 108,
                color: Color(0x24F59E0B),
              ),
            ),
            Positioned(
              bottom: 132,
              right: 30,
              child: _Plane(
                width: 124,
                height: 74,
                color: Color(0x2410B981),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plane extends StatelessWidget {
  const _Plane({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _AvatarOption {
  const _AvatarOption(this.icon, this.color, this.background);

  final IconData icon;
  final Color color;
  final Color background;
}
