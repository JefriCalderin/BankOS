import 'dart:convert';

import '../../domain/models/bank_models.dart';
import '../services/bankos_api_client.dart';
import '../services/secure_storage_service.dart';

class AuthRepository {
  AuthRepository({
    required BankOsApiClient apiClient,
    required KeyValueStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  static const _sessionKey = 'bankos_user_session_v1';
  static const _pinKey = 'bankos_local_pin_v1';
  static const _biometricEnabledKey = 'bankos_biometric_enabled_v1';
  static const _apiUrlKey = 'bankos_api_base_url_v1';

  final BankOsApiClient _apiClient;
  final KeyValueStorage _storage;

  UserSession? _currentSession;
  UserSession? get currentSession => _currentSession;

  Future<String?> loadSavedApiUrl() => _storage.read(_apiUrlKey);

  Future<void> saveApiUrl(String url) async {
    _apiClient.updateBaseUrl(url);
    await _storage.write(_apiUrlKey, _apiClient.baseUrl);
  }

  Future<UserSession?> restoreSession() async {
    final savedUrl = await _storage.read(_apiUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _apiClient.updateBaseUrl(savedUrl);
    }

    final raw = await _storage.read(_sessionKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cached = UserSession.fromJson(decoded);
      // Validate token is still accepted by backend; if offline, fall back to cached
      try {
        final meRes = await _apiClient.get(
          '/api/v1/auth/me',
          token: cached.accessToken,
        );
        final data = (meRes.body['data'] as Map).cast<String, dynamic>();
        final refreshed = UserSession(
          accessToken: cached.accessToken,
          user: UserProfile.fromJson(
            (data['user'] as Map).cast<String, dynamic>(),
          ),
          tenant: TenantInfo.fromJson(
            (data['tenant'] as Map).cast<String, dynamic>(),
          ),
        );
        _currentSession = refreshed;
        await _persistSession(refreshed);
        return refreshed;
      } on ApiError catch (e) {
        if (e.statusCode == 401) {
          await logout();
          return null;
        }
        _currentSession = cached;
        return cached;
      }
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<UserSession> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/auth/login',
      body: {
        'tenant_slug': tenantSlug.trim().toLowerCase(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = (response.body['data'] as Map).cast<String, dynamic>();
    final session = UserSession.fromJson(data);
    _currentSession = session;
    await _persistSession(session);

    // Ensure a default demo PIN (1234) is provisioned if user has not set one yet
    final existingPin = await _storage.read(_pinKey);
    if (existingPin == null || existingPin.isEmpty) {
      await _storage.write(_pinKey, '1234');
    }
    return session;
  }

  Future<void> updateCachedTenant(TenantInfo tenant) async {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(tenant: tenant);
    await _persistSession(_currentSession!);
  }

  Future<void> logout() async {
    _currentSession = null;
    await _storage.delete(_sessionKey);
  }

  // ==================== LOCAL 2FA (PIN & BIOMETRICS) ====================

  Future<String> getLocalPin() async {
    return (await _storage.read(_pinKey)) ?? '1234';
  }

  Future<void> setLocalPin(String pin) async {
    await _storage.write(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await getLocalPin();
    return stored == pin;
  }

  Future<bool> isBiometricEnabled() async {
    final raw = await _storage.read(_biometricEnabledKey);
    return raw == null || raw == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(_biometricEnabledKey, enabled ? 'true' : 'false');
  }

  Future<void> _persistSession(UserSession session) async {
    await _storage.write(_sessionKey, jsonEncode(session.toJson()));
  }
}
