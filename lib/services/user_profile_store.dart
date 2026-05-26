import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  const UserProfile({
    required this.isLoggedIn,
    required this.nickname,
    required this.identifier,
    required this.password,
    required this.avatarIndex,
  });

  final bool isLoggedIn;
  final String nickname;
  final String identifier;
  final String password;
  final int avatarIndex;

  String get phone => identifier;
  String get displayName => nickname.trim().isEmpty ? '临场记用户' : nickname;
  bool get hasRegisteredAccount =>
      identifier.trim().isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toAccountJson() {
    return {
      'nickname': nickname,
      'identifier': identifier,
      'password': password,
      'avatarIndex': avatarIndex,
    };
  }

  UserProfile copyWith({
    bool? isLoggedIn,
    String? nickname,
    String? identifier,
    String? phone,
    String? password,
    int? avatarIndex,
  }) {
    return UserProfile(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      nickname: nickname ?? this.nickname,
      identifier: identifier ?? phone ?? this.identifier,
      password: password ?? this.password,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }

  static UserProfile fromAccountJson(
    Map<String, dynamic> json, {
    required bool isLoggedIn,
  }) {
    return UserProfile(
      isLoggedIn: isLoggedIn,
      nickname: json['nickname'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatarIndex: json['avatarIndex'] as int? ?? 0,
    );
  }
}

class UserProfileStore {
  const UserProfileStore();

  static const _loggedInKey = 'profile.loggedIn';
  static const _nicknameKey = 'profile.nickname';
  static const _identifierKey = 'profile.identifier';
  static const _phoneKey = 'profile.phone';
  static const _passwordKey = 'profile.password';
  static const _avatarIndexKey = 'profile.avatarIndex';
  static const _accountsKey = 'profile.accounts.v1';
  static const _currentIdentifierKey = 'profile.currentIdentifier';

  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final currentIdentifier =
        prefs.getString(_currentIdentifierKey) ??
        prefs.getString(_identifierKey) ??
        prefs.getString(_phoneKey) ??
        '';
    final accounts = await loadAccounts();
    UserProfile? account;
    for (final item in accounts) {
      if (item.identifier == currentIdentifier) {
        account = item;
        break;
      }
    }
    if (account != null) {
      return account.copyWith(
        isLoggedIn: prefs.getBool(_loggedInKey) ?? false,
      );
    }

    return UserProfile(
      isLoggedIn: prefs.getBool(_loggedInKey) ?? false,
      nickname: prefs.getString(_nicknameKey) ?? '',
      identifier: currentIdentifier,
      password: prefs.getString(_passwordKey) ?? '',
      avatarIndex: prefs.getInt(_avatarIndexKey) ?? 0,
    );
  }

  Future<List<UserProfile>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    final accounts = <UserProfile>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            accounts.add(
              UserProfile.fromAccountJson(
                Map<String, dynamic>.from(item),
                isLoggedIn: false,
              ),
            );
          }
        }
      } catch (_) {}
    }

    final legacyIdentifier =
        prefs.getString(_identifierKey) ?? prefs.getString(_phoneKey) ?? '';
    final legacyPassword = prefs.getString(_passwordKey) ?? '';
    if (legacyIdentifier.isNotEmpty &&
        legacyPassword.isNotEmpty &&
        accounts.every((item) => item.identifier != legacyIdentifier)) {
      accounts.add(
        UserProfile(
          isLoggedIn: false,
          nickname: prefs.getString(_nicknameKey) ?? '',
          identifier: legacyIdentifier,
          password: legacyPassword,
          avatarIndex: prefs.getInt(_avatarIndexKey) ?? 0,
        ),
      );
      await _saveAccounts(prefs, accounts);
    }
    return accounts;
  }

  Future<UserProfile?> findAccount(String identifier) async {
    final accounts = await loadAccounts();
    for (final account in accounts) {
      if (account.identifier == identifier) {
        return account;
      }
    }
    return null;
  }

  Future<void> register(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await loadAccounts();
    final withoutSame = accounts
        .where((item) => item.identifier != profile.identifier)
        .toList();
    withoutSame.add(profile.copyWith(isLoggedIn: false));
    await _saveAccounts(prefs, withoutSame);
    await save(profile.copyWith(isLoggedIn: true));
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, profile.isLoggedIn);
    await prefs.setString(_nicknameKey, profile.nickname);
    await prefs.setString(_identifierKey, profile.identifier);
    await prefs.setString(_phoneKey, profile.identifier);
    await prefs.setString(_passwordKey, profile.password);
    await prefs.setInt(_avatarIndexKey, profile.avatarIndex);
    await prefs.setString(_currentIdentifierKey, profile.identifier);

    if (profile.hasRegisteredAccount) {
      final accounts = await loadAccounts();
      final next = accounts
          .where((item) => item.identifier != profile.identifier)
          .toList();
      next.add(profile.copyWith(isLoggedIn: false));
      await _saveAccounts(prefs, next);
    }
  }

  Future<void> logout() async {
    final profile = await load();
    await save(profile.copyWith(isLoggedIn: false));
  }

  Future<void> _saveAccounts(
    SharedPreferences prefs,
    List<UserProfile> accounts,
  ) async {
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((item) => item.toAccountJson()).toList()),
    );
  }
}
