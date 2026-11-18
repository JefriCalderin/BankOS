import '../models/domain_models.dart';

class StoredIdempotencyResponse {
  const StoredIdempotencyResponse({
    required this.statusCode,
    required this.responseBody,
    required this.expiresAt,
  });

  final int statusCode;
  final String responseBody;
  final DateTime expiresAt;
}

class FinancialExecutionResult {
  const FinancialExecutionResult({
    required this.transaction,
    this.sourceAccount,
    this.destinationAccount,
  });

  final TransactionRecord transaction;
  final BankAccount? sourceAccount;
  final BankAccount? destinationAccount;
}

abstract class BankStore {
  Future<void> initialize();
  Future<bool> ping();
  Future<void> close();

  // Tenants
  Future<Tenant?> findTenantBySlug(String slug);
  Future<Tenant?> findTenantById(String tenantId);
  Future<Tenant> createTenant(Tenant tenant);
  Future<Tenant> updateTenantConfig(String tenantId, TenantConfig config);

  // Users (strictly tenant-scoped)
  Future<User?> findUserByEmail(String tenantId, String email);
  Future<User?> findUserById(String tenantId, String userId);
  Future<List<User>> listUsersByTenant(String tenantId);
  Future<User> createUser(User user);

  // Accounts (strictly tenant-scoped)
  Future<BankAccount> createAccount(BankAccount account);
  Future<BankAccount?> findAccountById(String tenantId, String accountId);
  Future<BankAccount?> findAccountByNumber(
    String tenantId,
    String accountNumber,
  );
  Future<List<BankAccount>> listAccounts({
    required String tenantId,
    String? ownerUserId,
  });
  Future<BankAccount> updateAccountStatus({
    required String tenantId,
    required String accountId,
    required AccountStatus status,
    DateTime? deactivatedAt,
  });

  // Atomic Financial Operations (strictly tenant-scoped, row-locked)
  Future<FinancialExecutionResult> executeDeposit({
    required String tenantId,
    required String accountId,
    required double amount,
    required TransactionRecord record,
  });

  Future<FinancialExecutionResult> executeWithdrawal({
    required String tenantId,
    required String accountId,
    required double amount,
    required TransactionRecord record,
  });

  Future<FinancialExecutionResult> executeTransfer({
    required String tenantId,
    required String sourceAccountId,
    required String destinationAccountId,
    required double totalDebit,
    required double creditAmount,
    required TransactionRecord record,
  });

  Future<void> recordFailedTransaction(TransactionRecord record);

  // Transaction History (paginated, tenant-scoped)
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
  });

  // Immutable Audit Logs (append-only, tenant-scoped)
  Future<AuditLog> appendAuditLog(AuditLog log);
  Future<PaginatedResult<AuditLog>> listAuditLogs({
    required String tenantId,
    required int page,
    required int limit,
  });

  // Durable Idempotency Backup
  Future<StoredIdempotencyResponse?> getIdempotencyRecord({
    required String tenantId,
    required String userId,
    required String key,
  });

  Future<void> saveIdempotencyRecord({
    required String tenantId,
    required String userId,
    required String key,
    required int statusCode,
    required String responseBody,
    required DateTime expiresAt,
  });
}
