import '../models/api_response.dart';
import '../models/domain_models.dart';
import 'bank_store.dart';

/// Deterministic in-memory [BankStore] mirroring PostgreSQL constraints and
/// strict multitenant isolation for fast automated tests and local fallback.
class InMemoryBankStore implements BankStore {
  final Map<String, Tenant> _tenants = {};
  final Map<String, User> _users = {};
  final Map<String, BankAccount> _accounts = {};
  final List<TransactionRecord> _transactions = [];
  final List<AuditLog> _auditLogs = [];
  final Map<String, StoredIdempotencyResponse> _idempotency = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ping() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<Tenant?> findTenantBySlug(String slug) async {
    final normalized = slug.toLowerCase();
    for (final t in _tenants.values) {
      if (t.slug.toLowerCase() == normalized) return t;
    }
    return null;
  }

  @override
  Future<Tenant?> findTenantById(String tenantId) async => _tenants[tenantId];

  @override
  Future<Tenant> createTenant(Tenant tenant) async {
    final existing = await findTenantBySlug(tenant.slug);
    if (existing != null) {
      throw const AppException(
        statusCode: 409,
        code: 'TENANT_SLUG_EXISTS',
        message: 'Ya existe un tenant con ese slug',
      );
    }
    _tenants[tenant.id] = tenant;
    return tenant;
  }

  @override
  Future<Tenant> updateTenantConfig(
    String tenantId,
    TenantConfig config,
  ) async {
    final existing = _tenants[tenantId];
    if (existing == null) {
      throw const AppException(
        statusCode: 404,
        code: 'TENANT_NOT_FOUND',
        message: 'Tenant no encontrado',
      );
    }
    final updated = existing.copyWith(
      config: config,
      updatedAt: DateTime.now().toUtc(),
    );
    _tenants[tenantId] = updated;
    return updated;
  }

  @override
  Future<User?> findUserByEmail(String tenantId, String email) async {
    final lower = email.toLowerCase();
    for (final u in _users.values) {
      if (u.tenantId == tenantId && u.email.toLowerCase() == lower) return u;
    }
    return null;
  }

  @override
  Future<User?> findUserById(String tenantId, String userId) async {
    final u = _users[userId];
    if (u == null || u.tenantId != tenantId) return null;
    return u;
  }

  @override
  Future<List<User>> listUsersByTenant(String tenantId) async {
    return _users.values.where((u) => u.tenantId == tenantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<User> createUser(User user) async {
    final dup = await findUserByEmail(user.tenantId, user.email);
    if (dup != null) {
      throw const AppException(
        statusCode: 409,
        code: 'USER_EMAIL_EXISTS',
        message: 'Ya existe un usuario con ese correo en esta institución',
      );
    }
    _users[user.id] = user;
    return user;
  }

  @override
  Future<BankAccount> createAccount(BankAccount account) async {
    final dup = await findAccountByNumber(
      account.tenantId,
      account.accountNumber,
    );
    if (dup != null) {
      throw const AppException(
        statusCode: 409,
        code: 'ACCOUNT_NUMBER_EXISTS',
        message: 'El número de cuenta ya existe en este tenant',
      );
    }
    _accounts[account.id] = account;
    return account;
  }

  @override
  Future<BankAccount?> findAccountById(
    String tenantId,
    String accountId,
  ) async {
    final acc = _accounts[accountId];
    if (acc == null || acc.tenantId != tenantId) return null;
    return acc;
  }

  @override
  Future<BankAccount?> findAccountByNumber(
    String tenantId,
    String accountNumber,
  ) async {
    final normalized = accountNumber.trim().toUpperCase();
    for (final acc in _accounts.values) {
      if (acc.tenantId == tenantId &&
          acc.accountNumber.toUpperCase() == normalized) {
        return acc;
      }
    }
    return null;
  }

  @override
  Future<List<BankAccount>> listAccounts({
    required String tenantId,
    String? ownerUserId,
  }) async {
    return _accounts.values.where((a) {
      if (a.tenantId != tenantId) return false;
      if (ownerUserId != null && a.ownerUserId != ownerUserId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<BankAccount> updateAccountStatus({
    required String tenantId,
    required String accountId,
    required AccountStatus status,
    DateTime? deactivatedAt,
  }) async {
    final acc = await findAccountById(tenantId, accountId);
    if (acc == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta bancaria no encontrada en este tenant',
      );
    }
    final updated = acc.copyWith(
      status: status,
      deactivatedAt: deactivatedAt,
      clearDeactivatedAt: deactivatedAt == null,
    );
    _accounts[accountId] = updated;
    return updated;
  }

  @override
  Future<FinancialExecutionResult> executeDeposit({
    required String tenantId,
    required String accountId,
    required double amount,
    required TransactionRecord record,
  }) async {
    final acc = await findAccountById(tenantId, accountId);
    if (acc == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta destino no encontrada',
      );
    }
    if (!acc.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'ACCOUNT_INACTIVE',
        message: 'No se permiten operaciones sobre una cuenta ${acc.status.value}',
      );
    }
    final updated = acc.copyWith(balance: _round2(acc.balance + amount));
    _accounts[accountId] = updated;
    _transactions.add(record);
    return FinancialExecutionResult(
      transaction: record,
      destinationAccount: updated,
    );
  }

  @override
  Future<FinancialExecutionResult> executeWithdrawal({
    required String tenantId,
    required String accountId,
    required double amount,
    required TransactionRecord record,
  }) async {
    final acc = await findAccountById(tenantId, accountId);
    if (acc == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta de origen no encontrada',
      );
    }
    if (!acc.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'ACCOUNT_INACTIVE',
        message: 'No se permiten operaciones sobre una cuenta ${acc.status.value}',
      );
    }
    if (acc.balance < amount) {
      throw const AppException(
        statusCode: 422,
        code: 'INSUFFICIENT_FUNDS',
        message: 'Saldo insuficiente para realizar el retiro',
      );
    }
    final updated = acc.copyWith(balance: _round2(acc.balance - amount));
    _accounts[accountId] = updated;
    _transactions.add(record);
    return FinancialExecutionResult(
      transaction: record,
      sourceAccount: updated,
    );
  }

  @override
  Future<FinancialExecutionResult> executeTransfer({
    required String tenantId,
    required String sourceAccountId,
    required String destinationAccountId,
    required double totalDebit,
    required double creditAmount,
    required TransactionRecord record,
  }) async {
    final source = await findAccountById(tenantId, sourceAccountId);
    final dest = await findAccountById(tenantId, destinationAccountId);
    if (source == null || dest == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Una de las cuentas no existe dentro de esta institución',
      );
    }
    if (!source.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'SOURCE_ACCOUNT_INACTIVE',
        message: 'La cuenta de origen está ${source.status.value}',
      );
    }
    if (!dest.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'DESTINATION_ACCOUNT_INACTIVE',
        message: 'La cuenta destino está ${dest.status.value}',
      );
    }
    if (source.balance < totalDebit) {
      throw const AppException(
        statusCode: 422,
        code: 'INSUFFICIENT_FUNDS',
        message: 'Saldo insuficiente para cubrir el monto y la comisión',
      );
    }

    final updatedSource =
        source.copyWith(balance: _round2(source.balance - totalDebit));
    final updatedDest =
        dest.copyWith(balance: _round2(dest.balance + creditAmount));
    _accounts[sourceAccountId] = updatedSource;
    _accounts[destinationAccountId] = updatedDest;
    _transactions.add(record);

    return FinancialExecutionResult(
      transaction: record,
      sourceAccount: updatedSource,
      destinationAccount: updatedDest,
    );
  }

  @override
  Future<void> recordFailedTransaction(TransactionRecord record) async {
    _transactions.add(record);
  }

  @override
  Future<PaginatedResult<TransactionRecord>> listTransactions({
    required String tenantId,
    String? userIdFilter,
    String? accountId,
    TransactionType? type,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    required int page,
    required int limit,
  }) async {
    final ownedAccountIds = userIdFilter == null
        ? null
        : _accounts.values
            .where((a) => a.tenantId == tenantId && a.ownerUserId == userIdFilter)
            .map((a) => a.id)
            .toSet();

    final filtered = _transactions.where((t) {
      if (t.tenantId != tenantId) return false;
      if (userIdFilter != null) {
        final involved = t.initiatedByUserId == userIdFilter ||
            (t.sourceAccountId != null &&
                ownedAccountIds!.contains(t.sourceAccountId)) ||
            (t.destinationAccountId != null &&
                ownedAccountIds!.contains(t.destinationAccountId));
        if (!involved) return false;
      }
      if (accountId != null &&
          t.sourceAccountId != accountId &&
          t.destinationAccountId != accountId) {
        return false;
      }
      if (type != null && t.type != type) return false;
      if (status != null && t.status != status) return false;
      if (fromDate != null && t.createdAt.isBefore(fromDate)) return false;
      if (toDate != null && t.createdAt.isAfter(toDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final start = (page - 1) * limit;
    final items = start >= filtered.length
        ? <TransactionRecord>[]
        : filtered.sublist(start, (start + limit).clamp(0, filtered.length));

    return PaginatedResult(
      items: items,
      page: page,
      limit: limit,
      total: filtered.length,
    );
  }

  @override
  Future<AuditLog> appendAuditLog(AuditLog log) async {
    _auditLogs.add(log);
    return log;
  }

  @override
  Future<PaginatedResult<AuditLog>> listAuditLogs({
    required String tenantId,
    required int page,
    required int limit,
  }) async {
    final filtered = _auditLogs.where((l) => l.tenantId == tenantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = (page - 1) * limit;
    final items = start >= filtered.length
        ? <AuditLog>[]
        : filtered.sublist(start, (start + limit).clamp(0, filtered.length));

    return PaginatedResult(
      items: items,
      page: page,
      limit: limit,
      total: filtered.length,
    );
  }

  @override
  Future<StoredIdempotencyResponse?> getIdempotencyRecord({
    required String tenantId,
    required String userId,
    required String key,
  }) async {
    final composite = '$tenantId:$userId:$key';
    final record = _idempotency[composite];
    if (record == null) return null;
    if (DateTime.now().toUtc().isAfter(record.expiresAt)) {
      _idempotency.remove(composite);
      return null;
    }
    return record;
  }

  @override
  Future<void> saveIdempotencyRecord({
    required String tenantId,
    required String userId,
    required String key,
    required int statusCode,
    required String responseBody,
    required DateTime expiresAt,
  }) async {
    _idempotency['$tenantId:$userId:$key'] = StoredIdempotencyResponse(
      statusCode: statusCode,
      responseBody: responseBody,
      expiresAt: expiresAt,
    );
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;
}
