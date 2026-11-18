import 'package:flutter/foundation.dart';

import '../../../../data/repositories/banking_repository.dart';
import '../../../../data/services/bankos_api_client.dart';
import '../../../../domain/models/bank_models.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required BankingRepository bankingRepository})
      : _bankingRepository = bankingRepository;

  final BankingRepository _bankingRepository;

  List<BankAccount> _accounts = const [];
  List<BankAccount> get accounts => _accounts;

  List<BankAccount> get activeAccounts =>
      _accounts.where((a) => a.isActive).toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadAccounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _accounts = await _bankingRepository.fetchAccounts();
    } on ApiError catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las cuentas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
