import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalUser {
  const LocalUser({required this.name, required this.email});

  final String name;
  final String email;
}

class LocalAuthService {
  LocalAuthService._();

  static final LocalAuthService instance = LocalAuthService._();

  static const _accountsKey = 'smart_medreminder_local_accounts_v1';
  static const _sessionKey = 'smart_medreminder_local_session_v1';
  static const _passwordsKey = 'smart_medreminder_local_password_hashes_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<LocalUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final accounts = _readAccounts(prefs);

    if (accounts.any((account) => account['email'] == normalizedEmail)) {
      throw Exception('An account with this email already exists.');
    }

    final salt = _randomSalt();
    final hashes = await _readPasswordHashes();
    hashes[normalizedEmail] = _hashPassword(password, salt);
    await _writePasswordHashes(hashes);

    accounts.add({'name': name.trim(), 'email': normalizedEmail, 'salt': salt});
    await prefs.setString(_accountsKey, jsonEncode(accounts));

    final user = LocalUser(name: name.trim(), email: normalizedEmail);
    await _setSession(user);
    return user;
  }

  Future<LocalUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final accounts = _readAccounts(prefs);
    final account = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['email'] == normalizedEmail,
      orElse: () => null,
    );

    if (account == null) {
      throw Exception('No local account found for this email.');
    }

    final hashes = await _readPasswordHashes();
    final expectedHash = hashes[normalizedEmail];
    final salt = account['salt'] as String?;
    if (expectedHash == null || salt == null || _hashPassword(password, salt) != expectedHash) {
      throw Exception('Incorrect email or password.');
    }

    final user = LocalUser(
      name: account['name'] as String? ?? '',
      email: normalizedEmail,
    );
    await _setSession(user);
    return user;
  }

  Future<LocalUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final name = data['name'] as String?;
    final email = data['email'] as String?;
    if (name == null || email == null) return null;
    return LocalUser(name: name, email: email);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  List<Map<String, dynamic>> _readAccounts(SharedPreferences prefs) {
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, String>> _readPasswordHashes() async {
    final raw = await _secureStorage.read(key: _passwordsKey);
    if (raw == null) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> _writePasswordHashes(Map<String, String> hashes) {
    return _secureStorage.write(key: _passwordsKey, value: jsonEncode(hashes));
  }

  Future<void> _setSession(LocalUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({'name': user.name, 'email': user.email}),
    );
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }
}
