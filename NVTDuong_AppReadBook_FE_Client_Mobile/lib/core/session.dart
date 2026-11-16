import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';

class Session extends ChangeNotifier {
  Session() {
    api = ApiClient(tokenProvider: () => token, onUnauthorized: logout);
  }
  late final ApiClient api;
  final _storage = const FlutterSecureStorage();
  String? token;
  DateTime? expiresAt;
  UserProfile? user;
  bool ready = false;
  bool get authenticated =>
      token != null &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now().toUtc());
  Future<void> initialize() async {
    token = await _storage.read(key: 'access_token');
    final expiry = await _storage.read(key: 'access_expiry');
    final raw = await _storage.read(key: 'auth_user');
    expiresAt = DateTime.tryParse(expiry ?? '');
    if (raw != null) {
      try {
        user = UserProfile.from(jsonDecode(raw));
      } catch (_) {}
    }
    if (!authenticated) await _clear(notify: false);
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final r =
        await api.post(
              '/api/auth/login',
              body: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;
    await _accept(r);
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final r =
        await api.post(
              '/api/auth/register',
              body: {
                'fullName': name,
                'email': email,
                'password': password,
                'confirmPassword': confirmPassword,
              },
            )
            as Map<String, dynamic>;
    await _accept(r);
  }

  Future<void> _accept(Map<String, dynamic> r) async {
    token = s(r['accessToken']);
    expiresAt = DateTime.parse(s(r['expiresAtUtc'])!).toUtc();
    user = UserProfile.from(Map<String, dynamic>.from(r['user']));
    await _storage.write(key: 'access_token', value: token);
    await _storage.write(
      key: 'access_expiry',
      value: expiresAt!.toIso8601String(),
    );
    await _storage.write(key: 'auth_user', value: jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!authenticated) return;
    final r = await api.get('/api/users/me', auth: true);
    user = UserProfile.from(Map<String, dynamic>.from(r));
    await _storage.write(key: 'auth_user', value: jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> updateProfile(String fullName, String displayName) async {
    final r = await api.patch(
      '/api/users/me',
      auth: true,
      body: {
        'fullName': fullName,
        'displayName': displayName,
        'avatarUrl': user?.avatar,
      },
    );
    user = UserProfile.from(Map<String, dynamic>.from(r));
    await _storage.write(key: 'auth_user', value: jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> logout() => _clear(notify: true);
  Future<void> _clear({required bool notify}) async {
    token = null;
    expiresAt = null;
    user = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'access_expiry');
    await _storage.delete(key: 'auth_user');
    if (notify) notifyListeners();
  }
}
