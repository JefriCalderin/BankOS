import 'package:flutter/foundation.dart';

import '../../../../data/repositories/banking_repository.dart';
import '../../../../data/services/bankos_api_client.dart';
import '../../../../domain/models/bank_models.dart';

class OperationsViewModel extends ChangeNotifier {
  OperationsViewModel({required BankingRepository bankingRepository})
      : _bankingRepository = bankingRepository;

  final BankingRepository _bankingRepository;

  OperationKind _selectedKind = OperationKind.transfer;
  OperationKind get selectedKind => _selectedKind;

  DestinationLookup? _destinationLookup;
  DestinationLookup? get destinationLookup => _destinationLookup;

  bool _isLookingUp = false;
  bool get isLookingUp => _isLookingUp;

  bool _isQuoting = false;
  bool get isQuoting => _isQuoting;

  bool _isExecuting = false;
  bool get isExecuting => _isExecuting;

  OperationDraft? _pendingDraft;
  OperationDraft? get pendingDraft => _pendingDraft;

  NetworkInterruptedException? _interruptedError;
  NetworkInterruptedException? get interruptedError => _interruptedError;

  ExecutionReceipt? _receipt;
  ExecutionReceipt? get receipt => _receipt;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _manualRetryCount = 0;
  int get manualRetryCount => _manualRetryCount;

  void selectKind(OperationKind kind) {
    _selectedKind = kind;
    _errorMessage = null;
    notifyListeners();
  }

  void clearDestination() {
    _destinationLookup = null;
    notifyListeners();
  }

  Future<bool> lookupDestination(String accountNumber) async {
    if (accountNumber.trim().isEmpty) {
      _errorMessage = 'Ingrese el número de cuenta destino';
      notifyListeners();
      return false;
    }

    _isLookingUp = true;
    _errorMessage = null;
    _destinationLookup = null;
    notifyListeners();

    try {
      _destinationLookup =
          await _bankingRepository.lookupDestinationAccount(accountNumber);
      return true;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Error buscando cuenta destino: $e';
      return false;
    } finally {
      _isLookingUp = false;
      notifyListeners();
    }
  }

  /// Prepares an immutable [OperationDraft] with freshly generated
  /// `Idempotency-Key` and `X-Correlation-ID`. For transfers, queries the
  /// backend `/transactions/quote` endpoint to guarantee exact fee & FX values.
  Future<OperationDraft?> prepareDraft({
    required OperationKind kind,
    required BankAccount sourceAccount,
    required double amount,
    String? destinationAccountNumber,
    String? description,
  }) async {
    _isQuoting = true;
    _errorMessage = null;
    _interruptedError = null;
    _receipt = null;
    _manualRetryCount = 0;
    notifyListeners();

    try {
      if (amount <= 0) {
        _errorMessage = 'El monto debe ser mayor a cero';
        return null;
      }

      if (kind == OperationKind.transfer) {
        final destNumber = destinationAccountNumber?.trim() ?? '';
        if (destNumber.isEmpty) {
          _errorMessage = 'Debe especificar una cuenta destino';
          return null;
        }
        final quote = await _bankingRepository.quoteTransfer(
          sourceAccountNumber: sourceAccount.accountNumber,
          destinationAccountNumber: destNumber,
          amount: amount,
        );
        _pendingDraft = OperationDraft(
          kind: OperationKind.transfer,
          sourceAccountNumber: quote.sourceAccountNumber,
          sourceCurrency: quote.sourceCurrency,
          destinationAccountNumber: quote.destinationAccountNumber,
          destinationOwnerName: quote.destinationOwnerName,
          originalAmount: quote.originalAmount,
          feeAmount: quote.feeAmount,
          totalDebitAmount: quote.totalDebitAmount,
          convertedAmount: quote.convertedAmount,
          destinationCurrency: quote.destinationCurrency,
          exchangeRate: quote.exchangeRate,
          description: description,
        );
      } else {
        _pendingDraft = OperationDraft(
          kind: kind,
          sourceAccountNumber: sourceAccount.accountNumber,
          sourceCurrency: sourceAccount.currency,
          originalAmount: amount,
          feeAmount: 0,
          totalDebitAmount: kind == OperationKind.withdrawal ? amount : 0,
          convertedAmount: amount,
          destinationCurrency: sourceAccount.currency,
          exchangeRate: 1.0,
          description: description,
        );
      }

      return _pendingDraft;
    } on ApiError catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Error preparando la operación: $e';
      return null;
    } finally {
      _isQuoting = false;
      notifyListeners();
    }
  }

  /// Executes [draft] keeping its EXACT [OperationDraft.idempotencyKey] and
  /// [OperationDraft.correlationId]. Calling [retryPendingDraft] reuses the
  /// exact same draft without generating new keys.
  Future<bool> executePendingDraft({
    bool simulateResponseDrop = false,
    bool isManualRetry = false,
  }) async {
    final draft = _pendingDraft;
    if (draft == null) return false;

    _isExecuting = true;
    _errorMessage = null;
    if (isManualRetry) {
      _manualRetryCount++;
    }
    notifyListeners();

    try {
      final result = await _bankingRepository.executeOperation(
        draft,
        simulateResponseDrop: simulateResponseDrop,
      );
      _receipt = result;
      _interruptedError = null;
      return true;
    } on NetworkInterruptedException catch (e) {
      _interruptedError = e;
      return false;
    } on ApiError catch (e) {
      _errorMessage = '[${e.code}] ${e.message}';
      return false;
    } catch (e) {
      _errorMessage = 'Error inesperado: $e';
      return false;
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  void resetFlow() {
    _pendingDraft = null;
    _interruptedError = null;
    _receipt = null;
    _errorMessage = null;
    _manualRetryCount = 0;
    notifyListeners();
  }
}
