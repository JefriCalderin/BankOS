import 'package:flutter/material.dart';

import '../../../../data/repositories/banking_repository.dart';
import '../../../../data/services/bankos_api_client.dart';
import '../../../../domain/models/bank_models.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required BankingRepository bankingRepository})
      : _bankingRepository = bankingRepository;

  final BankingRepository _bankingRepository;

  List<TransactionItem> _items = const [];
  List<TransactionItem> get items => _items;

  PaginationMeta? _pagination;
  PaginationMeta? get pagination => _pagination;

  String? _selectedType; // null = all, 'deposit', 'withdrawal', 'transfer'
  String? get selectedType => _selectedType;

  DateTimeRange? _dateRange;
  DateTimeRange? get dateRange => _dateRange;

  String? _accountIdFilter;
  String? get accountIdFilter => _accountIdFilter;

  String? _accountNumberFilterLabel;
  String? get accountNumberFilterLabel => _accountNumberFilterLabel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get hasMore => _pagination?.hasNext ?? false;
  bool get hasActiveFilters =>
      _selectedType != null ||
      _dateRange != null ||
      _accountIdFilter != null;

  Future<void> setTypeFilter(String? type) async {
    _selectedType = type;
    await loadFirstPage();
  }

  Future<void> setDateRange(DateTimeRange? range) async {
    _dateRange = range;
    await loadFirstPage();
  }

  Future<void> setAccountFilter(String? accountId, {String? accountNumber}) async {
    _accountIdFilter = accountId;
    _accountNumberFilterLabel = accountNumber;
    await loadFirstPage();
  }

  Future<void> clearAllFilters() async {
    _selectedType = null;
    _dateRange = null;
    _accountIdFilter = null;
    _accountNumberFilterLabel = null;
    await loadFirstPage();
  }

  DateTime? get _effectiveToDate {
    if (_dateRange == null) return null;
    // Set to end of the day (23:59:59.999)
    final end = _dateRange!.end;
    return DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  }

  Future<void> loadFirstPage() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _bankingRepository.fetchTransactions(
        page: 1,
        limit: 15,
        type: _selectedType,
        accountId: _accountIdFilter,
        fromDate: _dateRange?.start,
        toDate: _effectiveToDate,
      );
      _items = result.items;
      _pagination = result.pagination;
    } on ApiError catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'No se pudo cargar el historial: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !hasMore) return;
    final nextPage = (_pagination?.page ?? 1) + 1;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _bankingRepository.fetchTransactions(
        page: nextPage,
        limit: 15,
        type: _selectedType,
        accountId: _accountIdFilter,
        fromDate: _dateRange?.start,
        toDate: _effectiveToDate,
      );
      _items = [..._items, ...result.items];
      _pagination = result.pagination;
    } on ApiError catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
