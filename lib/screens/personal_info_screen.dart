import 'package:flutter/material.dart';

import '../services/user_profile_store.dart';
import '../widgets/app_feedback_dialog.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final UserProfileStore _profileStore = const UserProfileStore();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileStore.load();
    if (!mounted) {
      return;
    }
    _nicknameController.text = profile.nickname;
    _phoneController.text = profile.phone;
    _passwordController.text = profile.password;
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _loginOrCreate() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      await AppFeedbackDialog.show(
        context,
        title: '无法登录',
        message: '请填写手机号和密码。',
        icon: Icons.lock_outline,
      );
      return;
    }

    final current = _profile ?? await _profileStore.load();
    if (current.phone.isNotEmpty &&
        (current.phone != phone || current.password != password)) {
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '登录失败',
        message: '手机号或密码不正确。',
        icon: Icons.error_outline,
      );
      return;
    }

    final profile = current.copyWith(
      isLoggedIn: true,
      phone: phone,
      password: password,
      nickname: current.nickname.isEmpty ? '临场记用户' : current.nickname,
    );
    await _profileStore.save(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _nicknameController.text = profile.nickname;
    });
    await AppFeedbackDialog.show(
      context,
      title: '已登录',
      message: '现在可以编辑个人信息。',
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _saveProfile() async {
    final current = _profile ?? await _profileStore.load();
    if (!current.isLoggedIn) {
      await AppFeedbackDialog.show(
        context,
        title: '需要先登录',
        message: '登录后才能编辑昵称、密码和手机号。',
        icon: Icons.lock_outline,
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      await AppFeedbackDialog.show(
        context,
        title: '保存失败',
        message: '手机号和密码不能为空。',
        icon: Icons.error_outline,
      );
      return;
    }

    final nickname = _nicknameController.text.trim();
    final profile = current.copyWith(
      nickname: nickname.isEmpty ? '临场记用户' : nickname,
      phone: phone,
      password: password,
    );
    await _profileStore.save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    await AppFeedbackDialog.show(
      context,
      title: '已保存',
      message: '个人信息已更新。',
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _logout() async {
    await _profileStore.logout();
    await _loadProfile();
  }

  String _avatarText(UserProfile? profile) {
    if (profile?.isLoggedIn != true) {
      return '登';
    }
    final name = profile!.displayName;
    return name.isEmpty ? '用' : name.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final isLoggedIn = profile?.isLoggedIn == true;

    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFFEAF1FF),
                          child: Text(
                            _avatarText(profile),
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isLoggedIn ? profile!.displayName : '未登录',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoggedIn ? '可以编辑个人资料' : '登录后可编辑个人资料',
                          style: const TextStyle(color: Color(0xFF60708F)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nicknameController,
                  enabled: isLoggedIn,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),
                if (isLoggedIn)
                  FilledButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存个人信息'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _loginOrCreate,
                    icon: const Icon(Icons.login),
                    label: const Text('登录 / 创建本地账号'),
                  ),
                if (isLoggedIn) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('退出登录'),
                  ),
                ],
              ],
            ),
    );
  }
}
