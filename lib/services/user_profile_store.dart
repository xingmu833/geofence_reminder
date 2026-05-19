import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  const UserProfile({
    required this.isLoggedIn,
    required this.nickname,
    required this.phone,
    required this.password,
  });

  final bool isLoggedIn;
  final String nickname;
  final String phone;
  final String password;

  String get displayName => nickname.trim().isEmpty ? '未登录用户' : nickname;

  UserProfile copyWith({
    bool? isLoggedIn,
    String? nickname,
    String? phone,
    String? password,
  }) {
    return UserProfile(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      password: password ?? this.password,
    );
  }
}

class UserProfileStore {
  const UserProfileStore();

  static const _loggedInKey = 'profile.loggedIn';
  static const _nicknameKey = 'profile.nickname';
  static const _phoneKey = 'profile.phone';
  static const _passwordKey = 'profile.password';

  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      isLoggedIn: prefs.getBool(_loggedInKey) ?? false,
      nickname: prefs.getString(_nicknameKey) ?? '',
      phone: prefs.getString(_phoneKey) ?? '',
      password: prefs.getString(_passwordKey) ?? '',
    );
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, profile.isLoggedIn);
    await prefs.setString(_nicknameKey, profile.nickname);
    await prefs.setString(_phoneKey, profile.phone);
    await prefs.setString(_passwordKey, profile.password);
  }

  Future<void> logout() async {
    final profile = await load();
    await save(profile.copyWith(isLoggedIn: false));
  }
}
