import 'package:flutter/material.dart';

import '../services/user_profile_store.dart';
import 'alarm_sound_screen.dart';
import 'personal_info_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileStore _profileStore = const UserProfileStore();
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileStore.load();
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
  }

  Future<void> _openPersonalInfo() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PersonalInfoScreen()));
    await _loadProfile();
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openRecycleBin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
  }

  Future<void> _openAlarmSound() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AlarmSoundScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final isLoggedIn = profile?.isLoggedIn == true;
    final name = isLoggedIn ? profile!.displayName : '点击登录';
    final phone = isLoggedIn ? profile!.phone : '';
    final subtitle = isLoggedIn
        ? (phone.isEmpty ? '还未绑定手机号' : phone)
        : '登录后可编辑个人资料';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _ProfileHeader(
              name: name,
              subtitle: subtitle,
              isLoggedIn: isLoggedIn,
              onTap: _openPersonalInfo,
            ),
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  _ProfileItem(
                    icon: Icons.person_outline,
                    title: '个人信息',
                    subtitle: '昵称、手机号和密码',
                    onTap: _openPersonalInfo,
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileItem(
                    icon: Icons.settings_outlined,
                    title: '设置',
                    subtitle: '权限、提醒偏好和数据管理',
                    onTap: _openSettings,
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileItem(
                    icon: Icons.music_note_outlined,
                    title: '闹钟铃声',
                    subtitle: '选择内置铃声或本地音频',
                    onTap: _openAlarmSound,
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileItem(
                    icon: Icons.delete_outline,
                    title: '回收站',
                    subtitle: '查看、还原或永久删除事件',
                    onTap: _openRecycleBin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.isLoggedIn,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final bool isLoggedIn;
  final VoidCallback onTap;

  String get _avatarText {
    if (!isLoggedIn || name.isEmpty) {
      return '登';
    }
    return name.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332563EB),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: Text(
                _avatarText,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
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
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(12),
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
