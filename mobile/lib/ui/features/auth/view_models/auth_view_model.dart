import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/bankos_api_client.dart';
import '../../../../domain/models/bank_models.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required BankOsApiClient apiClient,
  })  : _authRepository = authRepository,
        _apiClient = apiClient;

  final AuthRepository _authRepository;
  final BankOsApiClient _apiClient;

  UserSession? _session;
  UserSession? get session => _session;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String get currentApiUrl => _apiClient.baseUrl;

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();
    try {
      _session = await _authRepository.restoreSession();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> updateApiUrl(String url) async {
    if (url.trim().isEmpty) return;
    await _authRepository.saveApiUrl(url.trim());
    notifyListeners();
  }

  Future<bool> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _authRepository.login(
        tenantSlug: tenantSlug,
        email: email,
        password: password,
      );
      return true;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo iniciar sesión: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refreshCachedSession() {
    _session = _authRepository.currentSession;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _session = null;
    _errorMessage = null;
    notifyListeners();
  }
}
