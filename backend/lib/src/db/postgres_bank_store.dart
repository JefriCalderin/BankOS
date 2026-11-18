import 'dart:convert';
import 'package:postgres/postgres.dart';

import '../models/api_response.dart';
import '../models/domain_models.dart';
import 'bank_store.dart';
import 'schema.dart';

class PostgresBankStore implements BankStore {
  PostgresBankStore({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) : _pool = Pool.withEndpoints(
          [
            Endpoint(
              host: host,
              port: port,
              database: database,
              username: username,
              password: password,
            ),
          ],
          settings: PoolSettings(
            sslMode: SslMode.disable,
            maxConnectionCount: 15,
          ),
        );

  final Pool<void> _pool;

  @override
  Future<void> initialize() async {
    for (final ddl in bankOsMigrations) {
      await _pool.execute(ddl);
    }
  }

  @override
  Future<bool> ping() async {
    try {
      final result = await _pool.execute('SELECT 1');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _pool.close();
  }

  // ==================== TENANTS ====================

  @override
  Future<Tenant?> findTenantBySlug(String slug) async {
    final res = await _pool.execute(
      Sql.named('SELECT * FROM tenants WHERE slug = @slug LIMIT 1'),
      parameters: {'slug': slug.toLowerCase()},
    );
    if (res.isEmpty) return null;
    return _mapTenant(res.first.toColumnMap());
  }

  @override
  Future<Tenant?> findTenantById(String tenantId) async {
    final res = await _pool.execute(
      Sql.named('SELECT * FROM tenants WHERE id = @id::uuid LIMIT 1'),
      parameters: {'id': tenantId},
    );
    if (res.isEmpty) return null;
    return _mapTenant(res.first.toColumnMap());
  }

  @override
  Future<Tenant> createTenant(Tenant tenant) async {
    final res = await _pool.execute(
      Sql.named('''
        INSERT INTO tenants (
          id, slug, name, max_transaction_limit, transfer_fee_type,
          transfer_fee_value, base_currency, exchange_rates, webhook_url,
          created_at, updated_at
        ) VALUES (
          @id::uuid, @slug, @name, @max_limit, @fee_type,
          @fee_value, @base_currency, @exchange_rates::jsonb, @webhook_url,
          @created_at, @updated_at
        )
        RETURNING *
      '''),
      parameters: {
        'id': tenant.id,
        'slug': tenant.slug.toLowerCase(),
        'name': tenant.name,
        'max_limit': tenant.config.maxTransactionLimit,
        'fee_type': tenant.config.transferFeeType.value,
        'fee_value': tenant.config.transferFeeValue,
        'base_currency': tenant.config.baseCurrency.toUpperCase(),
        'exchange_rates': jsonEncode(tenant.config.exchangeRates),
        'webhook_url': tenant.config.webhookUrl,
        'created_at': tenant.createdAt.toUtc(),
        'updated_at': tenant.updatedAt.toUtc(),
      },
    );
    return _mapTenant(res.first.toColumnMap());
  }

  @override
  Future<Tenant> updateTenantConfig(
    String tenantId,
    TenantConfig config,
  ) async {
    final res = await _pool.execute(
      Sql.named('''
        UPDATE tenants
        SET max_transaction_limit = @max_limit,
            transfer_fee_type = @fee_type,
            transfer_fee_value = @fee_value,
            base_currency = @base_currency,
            exchange_rates = @exchange_rates::jsonb,
            webhook_url = @webhook_url,
            updated_at = NOW()
        WHERE id = @id::uuid
        RETURNING *
      '''),
      parameters: {
        'id': tenantId,
        'max_limit': config.maxTransactionLimit,
        'fee_type': config.transferFeeType.value,
        'fee_value': config.transferFeeValue,
        'base_currency': config.baseCurrency.toUpperCase(),
        'exchange_rates': jsonEncode(config.exchangeRates),
        'webhook_url': config.webhookUrl,
      },
    );
    if (res.isEmpty) {
      throw const AppException(
        statusCode: 404,
        code: 'TENANT_NOT_FOUND',
        message: 'Tenant no encontrado',
      );
    }
    return _mapTenant(res.first.toColumnMap());
  }

  // ==================== USERS ====================

  @override
  Future<User?> findUserByEmail(String tenantId, String email) async {
    final res = await _pool.execute(
      Sql.named('''
        SELECT * FROM users
        WHERE tenant_id = @tenant_id::uuid AND LOWER(email) = LOWER(@email)
        LIMIT 1
      '''),
      parameters: {'tenant_id': tenantId, 'email': email},
    );
    if (res.isEmpty) return null;
    return _mapUser(res.first.toColumnMap());
  }

  @override
  Future<User?> findUserById(String tenantId, String userId) async {
    final res = await _pool.execute(
      Sql.named('''
        SELECT * FROM users
        WHERE tenant_id = @tenant_id::uuid AND id = @user_id::uuid
        LIMIT 1
      '''),
      parameters: {'tenant_id': tenantId, 'user_id': userId},
    );
    if (res.isEmpty) return null;
    return _mapUser(res.first.toColumnMap());
  }

  @override
  Future<List<User>> listUsersByTenant(String tenantId) async {
    final res = await _pool.execute(
      Sql.named('''
        SELECT * FROM users
        WHERE tenant_id = @tenant_id::uuid
        ORDER BY created_at DESC
      '''),
      parameters: {'tenant_id': tenantId},
    );
    return res.map((row) => _mapUser(row.toColumnMap())).toList();
  }

  @override
  Future<User> createUser(User user) async {
    final res = await _pool.execute(
      Sql.named('''
        INSERT INTO users (
          id, tenant_id, email, full_name, password_hash, role, is_active, created_at
        ) VALUES (
          @id::uuid, @tenant_id::uuid, @email, @full_name, @password_hash, @role, @is_active, @created_at
        )
        RETURNING *
      '''),
      parameters: {
        'id': user.id,
        'tenant_id': user.tenantId,
        'email': user.email.toLowerCase(),
        'full_name': user.fullName,
        'password_hash': user.passwordHash,
        'role': user.role.value,
        'is_active': user.isActive,
        'created_at': user.createdAt.toUtc(),
      },
    );
    return _mapUser(res.first.toColumnMap());
  }

  // ==================== ACCOUNTS ====================

  @override
  Future<BankAccount> createAccount(BankAccount account) async {
    final res = await _pool.execute(
      Sql.named('''
        INSERT INTO accounts (
          id, tenant_id, account_number, owner_user_id, balance, currency, status, created_at
        ) VALUES (
          @id::uuid, @tenant_id::uuid, @account_number, @owner_user_id::uuid, @balance, @currency, @status, @created_at
        )
        RETURNING *
      '''),
      parameters: {
        'id': account.id,
        'tenant_id': account.tenantId,
        'account_number': account.accountNumber,
        'owner_user_id': account.ownerUserId,
        'balance': account.balance,
        'currency': account.currency.toUpperCase(),
        'status': account.status.value,
        'created_at': account.createdAt.toUtc(),
      },
    );
    return _mapAccount(res.first.toColumnMap(), ownerName: account.ownerName);
  }

  @override
  Future<BankAccount?> findAccountById(
    String tenantId,
    String accountId,
  ) async {
    final res = await _pool.execute(
      Sql.named('''
        SELECT a.*, u.full_name AS owner_name
        FROM accounts a
        JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
        WHERE a.tenant_id = @tenant_id::uuid AND a.id = @account_id::uuid
        LIMIT 1
      '''),
      parameters: {'tenant_id': tenantId, 'account_id': accountId},
    );
    if (res.isEmpty) return null;
    return _mapAccount(res.first.toColumnMap());
  }

  @override
  Future<BankAccount?> findAccountByNumber(
    String tenantId,
    String accountNumber,
  ) async {
    final res = await _pool.execute(
      Sql.named('''
        SELECT a.*, u.full_name AS owner_name
        FROM accounts a
        JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
        WHERE a.tenant_id = @tenant_id::uuid
          AND UPPER(a.account_number) = UPPER(@account_number)
        LIMIT 1
      '''),
      parameters: {
        'tenant_id': tenantId,
        'account_number': accountNumber.trim(),
      },
    );
    if (res.isEmpty) return null;
    return _mapAccount(res.first.toColumnMap());
  }

  @override
  Future<List<BankAccount>> listAccounts({
    required String tenantId,
    String? ownerUserId,
  }) async {
    final sql = ownerUserId == null
        ? '''
          SELECT a.*, u.full_name AS owner_name
          FROM accounts a
          JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
          WHERE a.tenant_id = @tenant_id::uuid
          ORDER BY a.created_at DESC
        '''
        : '''
          SELECT a.*, u.full_name AS owner_name
          FROM accounts a
          JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
          WHERE a.tenant_id = @tenant_id::uuid AND a.owner_user_id = @owner_user_id::uuid
          ORDER BY a.created_at DESC
        ''';

    final res = await _pool.execute(
      Sql.named(sql),
      parameters: {
        'tenant_id': tenantId,
        if (ownerUserId != null) 'owner_user_id': ownerUserId,
      },
    );
    return res.map((row) => _mapAccount(row.toColumnMap())).toList();
  }

  @override
  Future<BankAccount> updateAccountStatus({
    required String tenantId,
    required String accountId,
    required AccountStatus status,
    DateTime? deactivatedAt,
  }) async {
    final res = await _pool.execute(
      Sql.named('''
        UPDATE accounts a
        SET status = @status,
            deactivated_at = @deactivated_at
        FROM users u
        WHERE a.tenant_id = @tenant_id::uuid
          AND a.id = @account_id::uuid
          AND u.id = a.owner_user_id
          AND u.tenant_id = a.tenant_id
        RETURNING a.*, u.full_name AS owner_name
      '''),
      parameters: {
        'tenant_id': tenantId,
        'account_id': accountId,
        'status': status.value,
        'deactivated_at': deactivatedAt?.toUtc(),
      },
    );
    if (res.isEmpty) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta bancaria no encontrada en este tenant',
      );
    }
    return _mapAccount(res.first.toColumnMap());
  }

  // ==================== ATOMIC FINANCIAL OPERATIONS ====================

  @override
  Future<FinancialExecutionResult> executeDeposit({
    required String tenantId,
    required String accountId,
    required double amount,
    required TransactionRecord record,
  }) {
    return _pool.runTx((session) async {
      final locked = await session.execute(
        Sql.named('''
          SELECT a.*, u.full_name AS owner_name
          FROM accounts a
          JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
          WHERE a.tenant_id = @tenant_id::uuid AND a.id = @account_id::uuid
          FOR UPDATE OF a
        '''),
        parameters: {'tenant_id': tenantId, 'account_id': accountId},
      );
      if (locked.isEmpty) {
        throw const AppException(
          statusCode: 404,
          code: 'ACCOUNT_NOT_FOUND',
          message: 'Cuenta destino no encontrada',
        );
      }
      final account = _mapAccount(locked.first.toColumnMap());
      if (!account.status.isOperational) {
        throw AppException(
          statusCode: 422,
          code: 'ACCOUNT_INACTIVE',
          message: 'No se permiten operaciones sobre una cuenta ${account.status.value}',
        );
      }

      final newBalance = _round2(account.balance + amount);
      await session.execute(
        Sql.named('''
          UPDATE accounts
          SET balance = @balance
          WHERE tenant_id = @tenant_id::uuid AND id = @account_id::uuid
        '''),
        parameters: {
          'tenant_id': tenantId,
          'account_id': accountId,
          'balance': newBalance,
        },
      );

      final savedTx = await _insertTransaction(session, record);
      return FinancialExecutionResult(
        transaction: savedTx,
        destinationAccount: account.copyWith(balance: newBalance),
      );
    });
  }

  @override
  Future<FinancialExecutionResult> executeWithdrawal({
    required String tenantId,
    required String accountId,
    required double amount,
    required TransactionRecord record,
  }) {
    return _pool.runTx((session) async {
      final locked = await session.execute(
        Sql.named('''
          SELECT a.*, u.full_name AS owner_name
          FROM accounts a
          JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
          WHERE a.tenant_id = @tenant_id::uuid AND a.id = @account_id::uuid
          FOR UPDATE OF a
        '''),
        parameters: {'tenant_id': tenantId, 'account_id': accountId},
      );
      if (locked.isEmpty) {
        throw const AppException(
          statusCode: 404,
          code: 'ACCOUNT_NOT_FOUND',
          message: 'Cuenta de origen no encontrada',
        );
      }
      final account = _mapAccount(locked.first.toColumnMap());
      if (!account.status.isOperational) {
        throw AppException(
          statusCode: 422,
          code: 'ACCOUNT_INACTIVE',
          message: 'No se permiten operaciones sobre una cuenta ${account.status.value}',
        );
      }
      if (account.balance < amount) {
        throw const AppException(
          statusCode: 422,
          code: 'INSUFFICIENT_FUNDS',
          message: 'Saldo insuficiente para realizar el retiro',
        );
      }

      final newBalance = _round2(account.balance - amount);
      await session.execute(
        Sql.named('''
          UPDATE accounts
          SET balance = @balance
          WHERE tenant_id = @tenant_id::uuid AND id = @account_id::uuid
        '''),
        parameters: {
          'tenant_id': tenantId,
          'account_id': accountId,
          'balance': newBalance,
        },
      );

      final savedTx = await _insertTransaction(session, record);
      return FinancialExecutionResult(
        transaction: savedTx,
        sourceAccount: account.copyWith(balance: newBalance),
      );
    });
  }

  @override
  Future<FinancialExecutionResult> executeTransfer({
    required String tenantId,
    required String sourceAccountId,
    required String destinationAccountId,
    required double totalDebit,
    required double creditAmount,
    required TransactionRecord record,
  }) {
    return _pool.runTx((session) async {
      // Lock rows in deterministic UUID order to avoid deadlocks under concurrency.
      final orderedIds = [sourceAccountId, destinationAccountId]..sort();
      final lockedMap = <String, BankAccount>{};

      for (final id in orderedIds) {
        final res = await session.execute(
          Sql.named('''
            SELECT a.*, u.full_name AS owner_name
            FROM accounts a
            JOIN users u ON u.id = a.owner_user_id AND u.tenant_id = a.tenant_id
            WHERE a.tenant_id = @tenant_id::uuid AND a.id = @account_id::uuid
            FOR UPDATE OF a
          '''),
          parameters: {'tenant_id': tenantId, 'account_id': id},
        );
        if (res.isNotEmpty) {
          final acc = _mapAccount(res.first.toColumnMap());
          lockedMap[acc.id] = acc;
        }
      }

      final source = lockedMap[sourceAccountId];
      final dest = lockedMap[destinationAccountId];

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

      final newSourceBalance = _round2(source.balance - totalDebit);
      final newDestBalance = _round2(dest.balance + creditAmount);

      await session.execute(
        Sql.named('''
          UPDATE accounts SET balance = @balance
          WHERE tenant_id = @tenant_id::uuid AND id = @account_id::uuid
        '''),
        parameters: {
          'tenant_id': tenantId,
          'account_id': sourceAccountId,
          'balance': newSourceBalance,
        },
      );

      await session.execute(
        Sql.named('''
          UPDATE accounts SET balance = @balance
          WHERE tenant_id = @tenant_id::uuid AND id = @account_id::uuid
        '''),
        parameters: {
          'tenant_id': tenantId,
          'account_id': destinationAccountId,
          'balance': newDestBalance,
        },
      );

      final savedTx = await _insertTransaction(session, record);
      return FinancialExecutionResult(
        transaction: savedTx,
        sourceAccount: source.copyWith(balance: newSourceBalance),
        destinationAccount: dest.copyWith(balance: newDestBalance),
      );
    });
  }

  @override
  Future<void> recordFailedTransaction(TransactionRecord record) async {
    await _pool.runTx((session) async {
      await _insertTransaction(session, record);
    });
  }

  Future<TransactionRecord> _insertTransaction(
    TxSession session,
    TransactionRecord r,
  ) async {
    final res = await session.execute(
      Sql.named('''
        INSERT INTO transactions (
          id, tenant_id, initiated_by_user_id, type,
          source_account_id, source_account_number,
          destination_account_id, destination_account_number,
          original_amount, original_currency,
          converted_amount, destination_currency,
          exchange_rate, fee_amount, fee_currency, total_debited,
          status, failure_reason, idempotency_key, correlation_id,
          description, created_at
        ) VALUES (
          @id::uuid, @tenant_id::uuid, @initiated_by_user_id::uuid, @type,
          @source_account_id::uuid, @source_account_number,
          @destination_account_id::uuid, @destination_account_number,
          @original_amount, @original_currency,
          @converted_amount, @destination_currency,
          @exchange_rate, @fee_amount, @fee_currency, @total_debited,
          @status, @failure_reason, @idempotency_key, @correlation_id,
          @description, @created_at
        )
        RETURNING *
      '''),
      parameters: {
        'id': r.id,
        'tenant_id': r.tenantId,
        'initiated_by_user_id': r.initiatedByUserId,
        'type': r.type.value,
        'source_account_id': r.sourceAccountId,
        'source_account_number': r.sourceAccountNumber,
        'destination_account_id': r.destinationAccountId,
        'destination_account_number': r.destinationAccountNumber,
        'original_amount': r.originalAmount,
        'original_currency': r.originalCurrency,
        'converted_amount': r.convertedAmount,
        'destination_currency': r.destinationCurrency,
        'exchange_rate': r.exchangeRate,
        'fee_amount': r.feeAmount,
        'fee_currency': r.feeCurrency,
        'total_debited': r.totalDebited,
        'status': r.status.value,
        'failure_reason': r.failureReason,
        'idempotency_key': r.idempotencyKey,
        'correlation_id': r.correlationId,
        'description': r.description,
        'created_at': r.createdAt.toUtc(),
      },
    );
    return _mapTransaction(res.first.toColumnMap());
  }

  // ==================== TRANSACTION HISTORY ====================

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
    final where = <String>['t.tenant_id = @tenant_id::uuid'];
    final params = <String, Object?>{'tenant_id': tenantId};

    if (userIdFilter != null) {
      where.add('''
        (
          t.initiated_by_user_id = @user_id::uuid
          OR t.source_account_id IN (
            SELECT id FROM accounts WHERE tenant_id = @tenant_id::uuid AND owner_user_id = @user_id::uuid
          )
          OR t.destination_account_id IN (
            SELECT id FROM accounts WHERE tenant_id = @tenant_id::uuid AND owner_user_id = @user_id::uuid
          )
        )
      ''');
      params['user_id'] = userIdFilter;
    }

    if (accountId != null) {
      where.add(
        '(t.source_account_id = @account_id::uuid OR t.destination_account_id = @account_id::uuid)',
      );
      params['account_id'] = accountId;
    }
    if (type != null) {
      where.add('t.type = @type');
      params['type'] = type.value;
    }
    if (status != null) {
      where.add('t.status = @status');
      params['status'] = status.value;
    }
    if (fromDate != null) {
      where.add('t.created_at >= @from_date');
      params['from_date'] = fromDate.toUtc();
    }
    if (toDate != null) {
      where.add('t.created_at <= @to_date');
      params['to_date'] = toDate.toUtc();
    }

    final whereSql = where.join(' AND ');
    final countRes = await _pool.execute(
      Sql.named('SELECT COUNT(*)::int AS total FROM transactions t WHERE $whereSql'),
      parameters: params,
    );
    final total = (countRes.first.toColumnMap()['total'] as num).toInt();

    final offset = (page - 1) * limit;
    final rows = await _pool.execute(
      Sql.named('''
        SELECT t.* FROM transactions t
        WHERE $whereSql
        ORDER BY t.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {
        ...params,
        'limit': limit,
        'offset': offset,
      },
    );

    return PaginatedResult(
      items: rows.map((r) => _mapTransaction(r.toColumnMap())).toList(),
      page: page,
      limit: limit,
      total: total,
    );
  }

  // ==================== IMMUTABLE AUDIT LOGS ====================

  @override
  Future<AuditLog> appendAuditLog(AuditLog log) async {
    final res = await _pool.execute(
      Sql.named('''
        INSERT INTO audit_logs (
          id, tenant_id, actor_user_id, actor_email, action,
          entity_type, entity_id, previous_state, new_state,
          correlation_id, created_at
        ) VALUES (
          @id::uuid, @tenant_id::uuid, @actor_user_id::uuid, @actor_email, @action,
          @entity_type, @entity_id, @previous_state::jsonb, @new_state::jsonb,
          @correlation_id, @created_at
        )
        RETURNING *
      '''),
      parameters: {
        'id': log.id,
        'tenant_id': log.tenantId,
        'actor_user_id': log.actorUserId,
        'actor_email': log.actorEmail,
        'action': log.action,
        'entity_type': log.entityType,
        'entity_id': log.entityId,
        'previous_state':
            log.previousState != null ? jsonEncode(log.previousState) : null,
        'new_state': log.newState != null ? jsonEncode(log.newState) : null,
        'correlation_id': log.correlationId,
        'created_at': log.createdAt.toUtc(),
      },
    );
    return _mapAuditLog(res.first.toColumnMap());
  }

  @override
  Future<PaginatedResult<AuditLog>> listAuditLogs({
    required String tenantId,
    required int page,
    required int limit,
  }) async {
    final countRes = await _pool.execute(
      Sql.named(
        'SELECT COUNT(*)::int AS total FROM audit_logs WHERE tenant_id = @tenant_id::uuid',
      ),
      parameters: {'tenant_id': tenantId},
    );
    final total = (countRes.first.toColumnMap()['total'] as num).toInt();

    final offset = (page - 1) * limit;
    final rows = await _pool.execute(
      Sql.named('''
        SELECT * FROM audit_logs
        WHERE tenant_id = @tenant_id::uuid
        ORDER BY created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {'tenant_id': tenantId, 'limit': limit, 'offset': offset},
    );

    return PaginatedResult(
      items: rows.map((r) => _mapAuditLog(r.toColumnMap())).toList(),
      page: page,
      limit: limit,
      total: total,
    );
  }

  // ==================== DURABLE IDEMPOTENCY BACKUP ====================

  @override
  Future<StoredIdempotencyResponse?> getIdempotencyRecord({
    required String tenantId,
    required String userId,
    required String key,
  }) async {
    final res = await _pool.execute(
      Sql.named('''
        SELECT status_code, response_body, expires_at
        FROM idempotency_records
        WHERE tenant_id = @tenant_id::uuid
          AND user_id = @user_id::uuid
          AND idempotency_key = @key
          AND expires_at > NOW()
        LIMIT 1
      '''),
      parameters: {'tenant_id': tenantId, 'user_id': userId, 'key': key},
    );
    if (res.isEmpty) return null;
    final row = res.first.toColumnMap();
    return StoredIdempotencyResponse(
      statusCode: (row['status_code'] as num).toInt(),
      responseBody: row['response_body'] as String,
      expiresAt: _toDateTime(row['expires_at']),
    );
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
    await _pool.execute(
      Sql.named('''
        INSERT INTO idempotency_records (
          tenant_id, user_id, idempotency_key, status_code, response_body, expires_at
        ) VALUES (
          @tenant_id::uuid, @user_id::uuid, @key, @status_code, @response_body, @expires_at
        )
        ON CONFLICT (tenant_id, user_id, idempotency_key)
        DO UPDATE SET
          status_code = EXCLUDED.status_code,
          response_body = EXCLUDED.response_body,
          expires_at = EXCLUDED.expires_at
      '''),
      parameters: {
        'tenant_id': tenantId,
        'user_id': userId,
        'key': key,
        'status_code': statusCode,
        'response_body': responseBody,
        'expires_at': expiresAt.toUtc(),
      },
    );
  }

  // ==================== MAPPERS ====================

  Tenant _mapTenant(Map<String, dynamic> row) {
    final rawRates = _parseJsonMap(row['exchange_rates']);
    final rates = <String, double>{};
    for (final e in rawRates.entries) {
      rates[e.key.toUpperCase()] = _toDouble(e.value);
    }
    return Tenant(
      id: row['id'].toString(),
      slug: row['slug'] as String,
      name: row['name'] as String,
      config: TenantConfig(
        maxTransactionLimit: _toDouble(row['max_transaction_limit']),
        transferFeeType: FeeType.fromString(row['transfer_fee_type'] as String),
        transferFeeValue: _toDouble(row['transfer_fee_value']),
        baseCurrency: row['base_currency'] as String,
        exchangeRates: rates,
        webhookUrl: row['webhook_url'] as String?,
      ),
      createdAt: _toDateTime(row['created_at']),
      updatedAt: _toDateTime(row['updated_at']),
    );
  }

  User _mapUser(Map<String, dynamic> row) {
    return User(
      id: row['id'].toString(),
      tenantId: row['tenant_id'].toString(),
      email: row['email'] as String,
      fullName: row['full_name'] as String,
      passwordHash: row['password_hash'] as String,
      role: UserRole.fromString(row['role'] as String),
      isActive: row['is_active'] as bool,
      createdAt: _toDateTime(row['created_at']),
    );
  }

  BankAccount _mapAccount(Map<String, dynamic> row, {String? ownerName}) {
    return BankAccount(
      id: row['id'].toString(),
      tenantId: row['tenant_id'].toString(),
      accountNumber: row['account_number'] as String,
      ownerUserId: row['owner_user_id'].toString(),
      ownerName: ownerName ?? (row['owner_name'] as String? ?? ''),
      balance: _toDouble(row['balance']),
      currency: row['currency'] as String,
      status: AccountStatus.fromString(row['status'] as String),
      createdAt: _toDateTime(row['created_at']),
      deactivatedAt: row['deactivated_at'] != null
          ? _toDateTime(row['deactivated_at'])
          : null,
    );
  }

  TransactionRecord _mapTransaction(Map<String, dynamic> row) {
    return TransactionRecord(
      id: row['id'].toString(),
      tenantId: row['tenant_id'].toString(),
      initiatedByUserId: row['initiated_by_user_id'].toString(),
      type: TransactionType.fromString(row['type'] as String),
      sourceAccountId: row['source_account_id']?.toString(),
      sourceAccountNumber: row['source_account_number'] as String?,
      destinationAccountId: row['destination_account_id']?.toString(),
      destinationAccountNumber: row['destination_account_number'] as String?,
      originalAmount: _toDouble(row['original_amount']),
      originalCurrency: row['original_currency'] as String,
      convertedAmount: _toDouble(row['converted_amount']),
      destinationCurrency: row['destination_currency'] as String,
      exchangeRate: _toDouble(row['exchange_rate']),
      feeAmount: _toDouble(row['fee_amount']),
      feeCurrency: row['fee_currency'] as String,
      totalDebited: _toDouble(row['total_debited']),
      status: TransactionStatus.fromString(row['status'] as String),
      failureReason: row['failure_reason'] as String?,
      idempotencyKey: row['idempotency_key'] as String,
      correlationId: row['correlation_id'] as String,
      description: row['description'] as String?,
      createdAt: _toDateTime(row['created_at']),
    );
  }

  AuditLog _mapAuditLog(Map<String, dynamic> row) {
    return AuditLog(
      id: row['id'].toString(),
      tenantId: row['tenant_id'].toString(),
      actorUserId: row['actor_user_id'].toString(),
      actorEmail: row['actor_email'] as String,
      action: row['action'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      previousState: row['previous_state'] != null
          ? _parseJsonMap(row['previous_state'])
          : null,
      newState:
          row['new_state'] != null ? _parseJsonMap(row['new_state']) : null,
      correlationId: row['correlation_id'] as String,
      createdAt: _toDateTime(row['created_at']),
    );
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    throw FormatException('Cannot parse double from $value');
  }

  DateTime _toDateTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    throw FormatException('Cannot parse DateTime from $value');
  }

  Map<String, Object?> _parseJsonMap(Object? raw) {
    if (raw == null) return const {};
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return const {};
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;
}
