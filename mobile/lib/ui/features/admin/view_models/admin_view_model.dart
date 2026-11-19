import 'package:flutter/foundation.dart';

import '../../../../data/repositories/banking_repository.dart';
import '../../../../data/services/bankos_api_client.dart';
import '../../../../domain/models/bank_models.dart';

class AdminViewModel extends ChangeNotifier {
  AdminViewModel({required BankingRepository bankingRepository})
      : _bankingRepository = bankingRepository;

  final BankingRepository _bankingRepository;

  List<UserProfile> _users = const [];
  List<UserProfile> get users => _users;

  List<AuditLogItem> _auditLogs = const [];
  List<AuditLogItem> get auditLogs => _auditLogs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadAdminData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _bankingRepository.fetchTenantUsers(),
        _bankingRepository.fetchAuditLogs(),
      ]);
      _users = results[0] as List<UserProfile>;
      _auditLogs = results[1] as List<AuditLogItem>;
    } on ApiError catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Error cargando panel admin: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTenantConfig({
    required double maxTransactionLimit,
    required String transferFeeType,
    required double transferFeeValue,
    String? webhookUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _bankingRepository.updateTenantConfig(
        maxTransactionLimit: maxTransactionLimit,
        transferFeeType: transferFeeType,
        transferFeeValue: transferFeeValue,
        webhookUrl: webhookUrl,
      );
      _statusMessage = 'Configuración actualizada y registrada en auditoría';
      await loadAdminData();
      return true;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAccount({
    required String ownerUserId,
    required String currency,
    required double initialBalance,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final created = await _bankingRepository.createAccount(
        ownerUserId: ownerUserId,
        currency: currency,
        initialBalance: initialBalance,
      );
      _statusMessage = 'Cuenta ${created.accountNumber} creada exitosamente';
      await loadAdminData();
      return true;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String email,
    required String fullName,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final user = await _bankingRepository.createUser(
        email: email,
        fullName: fullName,
        password: password,
        role: role,
      );
      _statusMessage =
          'Usuario ${user.fullName} (${user.email}) creado exitosamente como ${user.role}';
      await loadAdminData();
      return true;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleAccountSoftDelete(BankAccount account) async {
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      if (account.isActive) {
        await _bankingRepository.softDeleteAccount(
          account.id,
          status: 'inactiva',
        );
        _statusMessage = 'Cuenta ${account.accountNumber} desactivada (Soft Delete)';
      } else {
        await _bankingRepository.updateAccountStatus(account.id, 'activa');
        _statusMessage = 'Cuenta ${account.accountNumber} reactivada';
      }
      await loadAdminData();
      return true;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
