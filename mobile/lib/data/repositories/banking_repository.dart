import '../../domain/models/bank_models.dart';
import '../services/bankos_api_client.dart';
import 'auth_repository.dart';

class BankingRepository {
  BankingRepository({
    required BankOsApiClient apiClient,
    required AuthRepository authRepository,
  })  : _apiClient = apiClient,
        _authRepository = authRepository;

  final BankOsApiClient _apiClient;
  final AuthRepository _authRepository;

  String _requireToken() {
    final token = _authRepository.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiError(
        statusCode: 401,
        code: 'NO_SESSION',
        message: 'Debe iniciar sesión primero',
      );
    }
    return token;
  }

  Future<List<BankAccount>> fetchAccounts() async {
    final res = await _apiClient.get(
      '/api/v1/accounts',
      token: _requireToken(),
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final rawList = (data['accounts'] as List?) ?? const [];
    return rawList
        .map((e) => BankAccount.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<DestinationLookup> lookupDestinationAccount(
    String accountNumber,
  ) async {
    final encoded = Uri.encodeComponent(accountNumber.trim().toUpperCase());
    final res = await _apiClient.get(
      '/api/v1/accounts/lookup/$encoded',
      token: _requireToken(),
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    return DestinationLookup.fromJson(data);
  }

  Future<TransferQuote> quoteTransfer({
    required String sourceAccountNumber,
    required String destinationAccountNumber,
    required double amount,
  }) async {
    final res = await _apiClient.post(
      '/api/v1/transactions/quote',
      token: _requireToken(),
      body: {
        'source_account_number': sourceAccountNumber,
        'destination_account_number': destinationAccountNumber,
        'amount': amount,
      },
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    return TransferQuote.fromJson(data);
  }

  /// Executes [draft] using its immutable [OperationDraft.idempotencyKey] and
  /// [OperationDraft.correlationId], ensuring every retry reuses the exact
  /// same keys.
  Future<ExecutionReceipt> executeOperation(
    OperationDraft draft, {
    bool simulateResponseDrop = false,
  }) async {
    final token = _requireToken();
    late final String path;
    late final Map<String, Object?> payload;

    switch (draft.kind) {
      case OperationKind.deposit:
        path = '/api/v1/transactions/deposit';
        payload = {
          'account_number': draft.sourceAccountNumber,
          'amount': draft.originalAmount,
          if (draft.description != null && draft.description!.isNotEmpty)
            'description': draft.description,
        };
      case OperationKind.withdrawal:
        path = '/api/v1/transactions/withdraw';
        payload = {
          'account_number': draft.sourceAccountNumber,
          'amount': draft.originalAmount,
          if (draft.description != null && draft.description!.isNotEmpty)
            'description': draft.description,
        };
      case OperationKind.transfer:
        path = '/api/v1/transactions/transfer';
        payload = {
          'source_account_number': draft.sourceAccountNumber,
          'destination_account_number': draft.destinationAccountNumber,
          'amount': draft.originalAmount,
          if (draft.description != null && draft.description!.isNotEmpty)
            'description': draft.description,
        };
    }

    final res = await _apiClient.postIdempotent(
      path,
      body: payload,
      token: token,
      idempotencyKey: draft.idempotencyKey,
      correlationId: draft.correlationId,
      simulateResponseDrop: simulateResponseDrop,
    );

    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final tx = TransactionItem.fromJson(
      (data['transaction'] as Map).cast<String, dynamic>(),
    );

    return ExecutionReceipt(
      transaction: tx,
      wasReplayed: res.wasIdempotencyReplayed,
      attemptsUsed: res.attemptsUsed,
      correlationId: res.correlationId,
    );
  }

  Future<PaginatedTransactions> fetchTransactions({
    int page = 1,
    int limit = 15,
    String? type,
    String? accountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (type != null && type.isNotEmpty) 'type': type,
      if (accountId != null && accountId.isNotEmpty) 'account_id': accountId,
      if (fromDate != null) 'from_date': fromDate.toUtc().toIso8601String(),
      if (toDate != null) 'to_date': toDate.toUtc().toIso8601String(),
    };

    final res = await _apiClient.get(
      '/api/v1/transactions',
      token: _requireToken(),
      queryParameters: query,
    );

    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final rawList = (data['transactions'] as List?) ?? const [];
    final meta = (res.body['meta'] as Map).cast<String, dynamic>();
    final pagination = PaginationMeta.fromJson(
      (meta['pagination'] as Map).cast<String, dynamic>(),
    );

    return PaginatedTransactions(
      items: rawList
          .map((e) => TransactionItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      pagination: pagination,
    );
  }

  // ==================== ADMIN OPERATIONS ====================

  Future<TenantInfo> updateTenantConfig({
    required double maxTransactionLimit,
    required String transferFeeType,
    required double transferFeeValue,
    String? webhookUrl,
  }) async {
    final res = await _apiClient.patch(
      '/api/v1/tenants/current/config',
      token: _requireToken(),
      body: {
        'max_transaction_limit': maxTransactionLimit,
        'transfer_fee_type': transferFeeType,
        'transfer_fee_value': transferFeeValue,
        'webhook_url': webhookUrl?.trim().isEmpty ?? true ? null : webhookUrl!.trim(),
      },
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final tenant = TenantInfo.fromJson(data);
    await _authRepository.updateCachedTenant(tenant);
    return tenant;
  }

  Future<List<UserProfile>> fetchTenantUsers() async {
    final res = await _apiClient.get(
      '/api/v1/users',
      token: _requireToken(),
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final raw = (data['users'] as List?) ?? const [];
    return raw
        .map((e) => UserProfile.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<UserProfile> createUser({
    required String email,
    required String fullName,
    required String password,
    required String role,
  }) async {
    final res = await _apiClient.post(
      '/api/v1/auth/register',
      token: _requireToken(),
      body: {
        'email': email.trim().toLowerCase(),
        'full_name': fullName.trim(),
        'password': password,
        'role': role,
      },
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    return UserProfile.fromJson(data);
  }

  Future<List<DispatchedWebhookItem>> fetchRecentWebhooks() async {
    final res = await _apiClient.get(
      '/api/v1/tenants/current/webhooks',
      token: _requireToken(),
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final list = (data['events'] as List?) ?? const [];
    return list
        .map((e) => DispatchedWebhookItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<BankAccount> createAccount({
    required String ownerUserId,
    required String currency,
    double initialBalance = 0,
  }) async {
    final res = await _apiClient.post(
      '/api/v1/accounts',
      token: _requireToken(),
      body: {
        'owner_user_id': ownerUserId,
        'currency': currency.toUpperCase(),
        'initial_balance': initialBalance,
      },
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    return BankAccount.fromJson(data);
  }

  Future<BankAccount> softDeleteAccount(
    String accountId, {
    String status = 'inactiva',
  }) async {
    final res = await _apiClient.delete(
      '/api/v1/accounts/$accountId',
      token: _requireToken(),
      queryParameters: {'status': status},
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    return BankAccount.fromJson(data);
  }

  Future<BankAccount> updateAccountStatus(
    String accountId,
    String status,
  ) async {
    final res = await _apiClient.patch(
      '/api/v1/accounts/$accountId/status',
      token: _requireToken(),
      body: {'status': status},
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    return BankAccount.fromJson(data);
  }

  Future<List<AuditLogItem>> fetchAuditLogs({
    int page = 1,
    int limit = 25,
  }) async {
    final res = await _apiClient.get(
      '/api/v1/audit-logs',
      token: _requireToken(),
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    final data = (res.body['data'] as Map).cast<String, dynamic>();
    final raw = (data['audit_logs'] as List?) ?? const [];
    return raw
        .map((e) => AuditLogItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
