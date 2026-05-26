import 'package:flutter/material.dart';

import '../services/user_profile_store.dart';
import '../widgets/app_feedback_dialog.dart';

enum _AuthMode { login, register }

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final UserProfileStore _profileStore = const UserProfileStore();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  UserProfile? _profile;
  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = true;
  int _avatarIndex = 0;

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
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileStore.load();
    if (!mounted) {
      return;
    }
    _nicknameController.text = profile.nickname;
    _identifierController.text = profile.identifier;
    _passwordController.clear();
    setState(() {
      _profile = profile;
      _avatarIndex = profile.avatarIndex.clamp(0, _avatars.length - 1).toInt();
      _isLoading = false;
    });
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    final current = _profile ?? await _profileStore.load();

    if (_mode == _AuthMode.login) {
      final account = _isTestAccount(identifier, password)
          ? UserProfile(
              isLoggedIn: true,
              nickname: '测试账号',
              identifier: identifier,
              password: password,
              avatarIndex: _avatarIndex,
            )
          : await _profileStore.findAccount(identifier);
      if (account == null || account.password != password) {
        await _show('登录失败', '账号或密码不正确。', Icons.error_outline);
        return;
      }
      final profile = account.copyWith(isLoggedIn: true);
      await _profileStore.save(profile);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _nicknameController.text = profile.nickname;
        _avatarIndex = profile.avatarIndex;
      });
      _passwordController.clear();
      await _show('已登录', '欢迎回来。', Icons.check_circle_outline);
      return;
    }

    final existing = await _profileStore.findAccount(identifier);
    if (existing != null) {
      await _show('账号已存在', '这个账号已注册，请直接登录或换一个手机号/邮箱。', Icons.info_outline);
      return;
    }

    final nickname = _nicknameController.text.trim();
    final profile = current.copyWith(
      isLoggedIn: true,
      nickname: nickname.isEmpty ? '临场记用户' : nickname,
      identifier: identifier,
      password: password,
      avatarIndex: _avatarIndex,
    );
    await _profileStore.register(profile);
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    _passwordController.clear();
    await _show('注册成功', '账号已创建并登录。', Icons.check_circle_outline);
  }

  Future<void> _saveProfile() async {
    final current = _profile ?? await _profileStore.load();
    if (!current.isLoggedIn) {
      await _show('需要先登录', '请先登录再修改个人资料。', Icons.lock_outline);
      return;
    }

    final password = _passwordController.text.trim();
    final nickname = _nicknameController.text.trim();
    final profile = current.copyWith(
      nickname: nickname.isEmpty ? '临场记用户' : nickname,
      password: password.isEmpty ? current.password : password,
      avatarIndex: _avatarIndex,
    );
    await _profileStore.save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    _passwordController.clear();
    await _show('已保存', '个人资料已更新。', Icons.check_circle_outline);
  }

  Future<void> _logout() async {
    await _profileStore.logout();
    await _loadProfile();
  }

  Future<void> _show(String title, String message, IconData icon) {
    return AppFeedbackDialog.show(
      context,
      title: title,
      message: message,
      icon: icon,
    );
  }

  bool _isTestAccount(String value, String password) {
    return value == '11111111111' && password == '123456c';
  }

  String? _validateIdentifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入手机号或邮箱';
    }
    if (_isTestAccount(text, _passwordController.text.trim())) {
      return null;
    }
    final phone = RegExp(r'^1[3-9]\d{9}$');
    final email = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    if (!phone.hasMatch(text) && !email.hasMatch(text)) {
      return '请输入有效的手机号或邮箱';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入密码';
    }
    if (_isTestAccount(_identifierController.text.trim(), text)) {
      return null;
    }
    if (text.length < 6) {
      return '密码至少 6 位';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final isLoggedIn = profile?.isLoggedIn == true;
    final avatar = _avatars[_avatarIndex.clamp(0, _avatars.length - 1).toInt()];

    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: Stack(
        children: [
          const _ProfileBackdrop(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _IdentityCard(
                        avatar: avatar,
                        title: isLoggedIn ? profile!.displayName : '未登录',
                        subtitle: isLoggedIn ? profile!.identifier : '登录或注册后管理个人资料',
                      ),
                      const SizedBox(height: 16),
                      if (!isLoggedIn) _AuthPanel() else _ProfileForm(profile!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _AuthPanel() {
    return Form(
      key: _formKey,
      child: _GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<_AuthMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AuthMode.login,
                  icon: Icon(Icons.login),
                  label: Text('登录'),
                ),
                ButtonSegment(
                  value: _AuthMode.register,
                  icon: Icon(Icons.person_add_alt_1),
                  label: Text('注册'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (values) {
                setState(() => _mode = values.first);
              },
            ),
            const SizedBox(height: 16),
            if (_mode == _AuthMode.register) ...[
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: '账号昵称',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              _AvatarPicker(),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _identifierController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateIdentifier,
              decoration: const InputDecoration(
                labelText: '手机号 / 邮箱',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              validator: _validatePassword,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitAuth,
              icon: Icon(_mode == _AuthMode.login ? Icons.login : Icons.person_add_alt_1),
              label: Text(_mode == _AuthMode.login ? '登录账号' : '创建账号'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ProfileForm(UserProfile profile) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarPicker(),
          const SizedBox(height: 16),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: '账号昵称',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: profile.identifier,
            enabled: false,
            decoration: const InputDecoration(
              labelText: '手机号 / 邮箱',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '新密码（不填则不修改）',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存个人资料'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  Widget _AvatarPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _avatars.length; i++)
          _AvatarButton(
            option: _avatars[i],
            selected: i == _avatarIndex,
            onTap: () => setState(() => _avatarIndex = i),
          ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.avatar,
    required this.title,
    required this.subtitle,
  });

  final _AvatarOption avatar;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: avatar.background,
            child: Icon(avatar.icon, color: avatar.color, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10203F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF60708F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _AvatarOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: option.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? option.color : Colors.white,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: option.color.withValues(alpha: selected ? 0.24 : 0.1),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(option.icon, color: option.color),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x182563EB),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
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
            colors: [Color(0xFFF7FAFF), Color(0xFFF0F9F6), Color(0xFFFFFBF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: 90, right: -34, child: _Plane(width: 154, height: 88, color: Color(0x2E38BDF8))),
            Positioned(top: 250, left: -48, child: _Plane(width: 170, height: 96, color: Color(0x24F59E0B))),
            Positioned(bottom: 90, right: 22, child: _Plane(width: 120, height: 68, color: Color(0x2410B981))),
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
