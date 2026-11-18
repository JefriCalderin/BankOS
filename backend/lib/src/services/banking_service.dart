import 'dart:math';
import 'package:uuid/uuid.dart';

import '../db/bank_store.dart';
import '../models/api_response.dart';
import '../models/domain_models.dart';
import '../security/jwt_service.dart';
import '../security/password_hasher.dart';
import 'currency_service.dart';
import 'webhook_service.dart';

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.user,
    required this.tenant,
  });

  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final User user;
  final Tenant tenant;

  Map<String, Object?> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresInSeconds,
        'user': user.toSafeJson(),
        'tenant': tenant.toJson(),
      };
}

class TenantRegistrationResult {
  const TenantRegistrationResult({
    required this.tenant,
    required this.adminUser,
    required this.accessToken,
  });

  final Tenant tenant;
  final User adminUser;
  final String accessToken;

  Map<String, Object?> toJson() => {
        'tenant': tenant.toJson(),
        'admin_user': adminUser.toSafeJson(),
        'access_token': accessToken,
      };
}

class BankingService {
  BankingService({
    required BankStore store,
    required JwtService jwtService,
    required CurrencyService currencyService,
    required WebhookService webhookService,
  })  : _store = store,
        _jwtService = jwtService,
        _currencyService = currencyService,
        _webhookService = webhookService;

  final BankStore _store;
  final JwtService _jwtService;
  final CurrencyService _currencyService;
  final WebhookService _webhookService;
  static const Uuid _uuid = Uuid();

  // ==================== TENANTS ====================

  Future<TenantRegistrationResult> registerTenant({
    required String name,
    required String slug,
    required TenantConfig config,
    required String adminEmail,
    required String adminFullName,
    required String adminPassword,
    required String correlationId,
  }) async {
    final cleanSlug = slug.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9\-]{2,50}$').hasMatch(cleanSlug)) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_TENANT_SLUG',
        message:
            'El slug debe tener entre 3 y 50 caracteres alfanuméricos o guiones',
      );
    }
    if (name.trim().length < 2) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_TENANT_NAME',
        message: 'El nombre de la institución es obligatorio',
      );
    }
    _validateTenantConfig(config);
    _validatePasswordStrength(adminPassword);

    final existing = await _store.findTenantBySlug(cleanSlug);
    if (existing != null) {
      throw const AppException(
        statusCode: 409,
        code: 'TENANT_SLUG_EXISTS',
        message: 'Ya existe una institución registrada con ese slug',
      );
    }

    final now = DateTime.now().toUtc();
    final tenant = await _store.createTenant(
      Tenant(
        id: _uuid.v4(),
        slug: cleanSlug,
        name: name.trim(),
        config: config,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final admin = await _store.createUser(
      User(
        id: _uuid.v4(),
        tenantId: tenant.id,
        email: adminEmail.trim().toLowerCase(),
        fullName: adminFullName.trim(),
        passwordHash: PasswordHasher.hash(adminPassword),
        role: UserRole.administrador,
        isActive: true,
        createdAt: now,
      ),
    );

    await _store.appendAuditLog(
      AuditLog(
        id: _uuid.v4(),
        tenantId: tenant.id,
        actorUserId: admin.id,
        actorEmail: admin.email,
        action: 'TENANT_CREATED',
        entityType: 'tenant',
        entityId: tenant.id,
        newState: tenant.toJson(),
        correlationId: correlationId,
        createdAt: now,
      ),
    );

    final token = _jwtService.sign(
      tenantId: tenant.id,
      tenantSlug: tenant.slug,
      userId: admin.id,
      email: admin.email,
      role: admin.role,
    );

    return TenantRegistrationResult(
      tenant: tenant,
      adminUser: admin,
      accessToken: token,
    );
  }

  Future<Tenant> getCurrentTenant(AuthContext auth) async {
    final tenant = await _store.findTenantById(auth.tenantId);
    if (tenant == null) {
      throw const AppException(
        statusCode: 404,
        code: 'TENANT_NOT_FOUND',
        message: 'Tenant no encontrado',
      );
    }
    return tenant;
  }

  Future<Tenant> updateTenantConfig({
    required AuthContext auth,
    required TenantConfig newConfig,
    required String correlationId,
  }) async {
    _validateTenantConfig(newConfig);
    final previous = await getCurrentTenant(auth);
    final updated = await _store.updateTenantConfig(auth.tenantId, newConfig);

    await _store.appendAuditLog(
      AuditLog(
        id: _uuid.v4(),
        tenantId: auth.tenantId,
        actorUserId: auth.userId,
        actorEmail: auth.email,
        action: 'TENANT_CONFIG_UPDATED',
        entityType: 'tenant',
        entityId: auth.tenantId,
        previousState: previous.config.toJson(),
        newState: updated.config.toJson(),
        correlationId: correlationId,
        createdAt: DateTime.now().toUtc(),
      ),
    );

    return updated;
  }

  // ==================== AUTH & USERS ====================

  Future<LoginResult> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final tenant = await _store.findTenantBySlug(tenantSlug.trim().toLowerCase());
    if (tenant == null) {
      throw const AppException(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Credenciales inválidas o institución no encontrada',
      );
    }

    final user =
        await _store.findUserByEmail(tenant.id, email.trim().toLowerCase());
    if (user == null ||
        !user.isActive ||
        !PasswordHasher.verify(password, user.passwordHash)) {
      throw const AppException(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Credenciales inválidas o usuario inactivo',
      );
    }

    final token = _jwtService.sign(
      tenantId: tenant.id,
      tenantSlug: tenant.slug,
      userId: user.id,
      email: user.email,
      role: user.role,
    );

    return LoginResult(
      accessToken: token,
      tokenType: 'Bearer',
      expiresInSeconds: _jwtService.expiryHours * 3600,
      user: user,
      tenant: tenant,
    );
  }

  Future<User> createUserInTenant({
    required AuthContext auth,
    required String email,
    required String fullName,
    required String password,
    required UserRole role,
    required String correlationId,
  }) async {
    if (!email.contains('@')) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_EMAIL',
        message: 'Correo electrónico inválido',
      );
    }
    _validatePasswordStrength(password);

    final existing =
        await _store.findUserByEmail(auth.tenantId, email.trim().toLowerCase());
    if (existing != null) {
      throw const AppException(
        statusCode: 409,
        code: 'USER_EMAIL_EXISTS',
        message: 'Ya existe un usuario con este correo dentro del tenant',
      );
    }

    final now = DateTime.now().toUtc();
    final created = await _store.createUser(
      User(
        id: _uuid.v4(),
        tenantId: auth.tenantId,
        email: email.trim().toLowerCase(),
        fullName: fullName.trim(),
        passwordHash: PasswordHasher.hash(password),
        role: role,
        isActive: true,
        createdAt: now,
      ),
    );

    await _store.appendAuditLog(
      AuditLog(
        id: _uuid.v4(),
        tenantId: auth.tenantId,
        actorUserId: auth.userId,
        actorEmail: auth.email,
        action: 'USER_CREATED',
        entityType: 'user',
        entityId: created.id,
        newState: created.toSafeJson(),
        correlationId: correlationId,
        createdAt: now,
      ),
    );

    return created;
  }

  Future<User> getUserProfile(AuthContext auth) async {
    final user = await _store.findUserById(auth.tenantId, auth.userId);
    if (user == null) {
      throw const AppException(
        statusCode: 404,
        code: 'USER_NOT_FOUND',
        message: 'Usuario no encontrado',
      );
    }
    return user;
  }

  Future<List<User>> listUsers(AuthContext auth) {
    return _store.listUsersByTenant(auth.tenantId);
  }

  // ==================== ACCOUNTS ====================

  Future<BankAccount> createAccount({
    required AuthContext auth,
    required String ownerUserId,
    required String currency,
    double initialBalance = 0,
    String? customAccountNumber,
    required String correlationId,
  }) async {
    if (initialBalance < 0) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_INITIAL_BALANCE',
        message: 'El saldo inicial no puede ser negativo',
      );
    }

    final cleanCurrency = currency.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_CURRENCY',
        message: 'La moneda debe ser un código ISO de 3 letras (ej. COP, USD, EUR)',
      );
    }

    // Strict tenant check: owner MUST belong to this tenant
    final owner = await _store.findUserById(auth.tenantId, ownerUserId);
    if (owner == null) {
      throw const AppException(
        statusCode: 404,
        code: 'OWNER_NOT_FOUND',
        message: 'El titular especificado no pertenece a esta institución',
      );
    }

    final prefix = auth.tenantSlug.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final shortPrefix =
        (prefix.length >= 3 ? prefix.substring(0, 3) : prefix).toUpperCase();
    final rng = Random.secure();
    final generatedNumber = customAccountNumber?.trim().toUpperCase() ??
        '$shortPrefix-$cleanCurrency-${100000 + rng.nextInt(899999)}';

    final now = DateTime.now().toUtc();
    final created = await _store.createAccount(
      BankAccount(
        id: _uuid.v4(),
        tenantId: auth.tenantId,
        accountNumber: generatedNumber,
        ownerUserId: owner.id,
        ownerName: owner.fullName,
        balance: _currencyService.round2(initialBalance),
        currency: cleanCurrency,
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await _store.appendAuditLog(
      AuditLog(
        id: _uuid.v4(),
        tenantId: auth.tenantId,
        actorUserId: auth.userId,
        actorEmail: auth.email,
        action: 'ACCOUNT_CREATED',
        entityType: 'account',
        entityId: created.id,
        newState: created.toJson(),
        correlationId: correlationId,
        createdAt: now,
      ),
    );

    return created;
  }

  Future<List<BankAccount>> listAccounts(AuthContext auth) {
    final ownerFilter =
        auth.role == UserRole.administrador ? null : auth.userId;
    return _store.listAccounts(
      tenantId: auth.tenantId,
      ownerUserId: ownerFilter,
    );
  }

  Future<BankAccount> getAccountByNumber({
    required AuthContext auth,
    required String accountNumber,
  }) async {
    final account =
        await _store.findAccountByNumber(auth.tenantId, accountNumber);
    if (account == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta bancaria no encontrada',
      );
    }
    if (auth.role != UserRole.administrador &&
        account.ownerUserId != auth.userId) {
      throw const AppException(
        statusCode: 403,
        code: 'FORBIDDEN_ACCOUNT_ACCESS',
        message: 'No tiene permisos para consultar los detalles de esta cuenta',
      );
    }
    return account;
  }

  /// Allows any authenticated user in the same tenant to lookup a destination
  /// account number for transfers (never leaks cross-tenant accounts).
  Future<BankAccount> lookupDestinationAccount({
    required AuthContext auth,
    required String accountNumber,
  }) async {
    final account =
        await _store.findAccountByNumber(auth.tenantId, accountNumber);
    if (account == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta destino no encontrada en esta institución',
      );
    }
    return account;
  }

  /// Soft delete: marks account as `inactiva` or `bloqueada` without removing DB row.
  Future<BankAccount> updateAccountStatus({
    required AuthContext auth,
    required String accountId,
    required AccountStatus newStatus,
    required String correlationId,
  }) async {
    final previous = await _store.findAccountById(auth.tenantId, accountId);
    if (previous == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta no encontrada en esta institución',
      );
    }

    final now = DateTime.now().toUtc();
    final updated = await _store.updateAccountStatus(
      tenantId: auth.tenantId,
      accountId: accountId,
      status: newStatus,
      deactivatedAt: newStatus == AccountStatus.activa ? null : now,
    );

    await _store.appendAuditLog(
      AuditLog(
        id: _uuid.v4(),
        tenantId: auth.tenantId,
        actorUserId: auth.userId,
        actorEmail: auth.email,
        action: newStatus == AccountStatus.activa
            ? 'ACCOUNT_REACTIVATED'
            : 'ACCOUNT_DEACTIVATED',
        entityType: 'account',
        entityId: accountId,
        previousState: {'status': previous.status.value},
        newState: {
          'status': updated.status.value,
          'deactivated_at': updated.deactivatedAt?.toIso8601String(),
        },
        correlationId: correlationId,
        createdAt: now,
      ),
    );

    final tenant = await getCurrentTenant(auth);
    if (!newStatus.isOperational) {
      _webhookService.dispatchAsync(
        webhookUrl: tenant.config.webhookUrl,
        tenantId: tenant.id,
        tenantSlug: tenant.slug,
        eventType: 'account.deactivated',
        correlationId: correlationId,
        data: updated.toJson(),
      );
    }

    return updated;
  }

  // ==================== FINANCIAL OPERATIONS ====================

  Future<TransferQuote> quoteTransfer({
    required AuthContext auth,
    required String sourceAccountNumber,
    required String destinationAccountNumber,
    required double amount,
  }) async {
    _validatePositiveAmount(amount);
    final tenant = await getCurrentTenant(auth);

    final source =
        await _store.findAccountByNumber(auth.tenantId, sourceAccountNumber);
    if (source == null) {
      throw const AppException(
        statusCode: 404,
        code: 'SOURCE_ACCOUNT_NOT_FOUND',
        message: 'Cuenta de origen no encontrada',
      );
    }
    _ensureCanOperateOnAccount(auth, source);
    if (!source.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'SOURCE_ACCOUNT_INACTIVE',
        message: 'La cuenta de origen está ${source.status.value}',
      );
    }

    final dest = await _store.findAccountByNumber(
      auth.tenantId,
      destinationAccountNumber,
    );
    if (dest == null) {
      throw const AppException(
        statusCode: 404,
        code: 'DESTINATION_ACCOUNT_NOT_FOUND',
        message: 'Cuenta destino no encontrada en esta institución',
      );
    }
    if (source.id == dest.id) {
      throw const AppException(
        statusCode: 400,
        code: 'SAME_ACCOUNT_TRANSFER',
        message: 'No puede transferir a la misma cuenta',
      );
    }
    if (!dest.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'DESTINATION_ACCOUNT_INACTIVE',
        message: 'La cuenta destino está ${dest.status.value}',
      );
    }

    _currencyService.validateMaxLimit(
      tenant.config,
      amount: amount,
      currency: source.currency,
    );

    final fee = _currencyService.calculateTransferFee(tenant.config, amount);
    final totalDebit = _currencyService.round2(amount + fee);
    final conversion = _currencyService.convert(
      tenant.config,
      amount: amount,
      fromCurrency: source.currency,
      toCurrency: dest.currency,
    );

    return TransferQuote(
      sourceAccountNumber: source.accountNumber,
      destinationAccountNumber: dest.accountNumber,
      destinationOwnerName: dest.ownerName,
      originalAmount: _currencyService.round2(amount),
      sourceCurrency: source.currency,
      feeAmount: fee,
      feeType: tenant.config.transferFeeType,
      feeRateValue: tenant.config.transferFeeValue,
      totalDebitAmount: totalDebit,
      exchangeRate: conversion.rate,
      convertedAmount: conversion.convertedAmount,
      destinationCurrency: dest.currency,
      hasCurrencyConversion: source.currency != dest.currency,
    );
  }

  Future<FinancialExecutionResult> deposit({
    required AuthContext auth,
    required String accountNumber,
    required double amount,
    required String idempotencyKey,
    required String correlationId,
    String? description,
  }) async {
    _validatePositiveAmount(amount);
    final tenant = await getCurrentTenant(auth);
    final account =
        await _store.findAccountByNumber(auth.tenantId, accountNumber);
    if (account == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta no encontrada en esta institución',
      );
    }
    _ensureCanOperateOnAccount(auth, account);

    if (!account.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'ACCOUNT_INACTIVE',
        message: 'No se puede depositar en una cuenta ${account.status.value}',
      );
    }

    _currencyService.validateMaxLimit(
      tenant.config,
      amount: amount,
      currency: account.currency,
    );

    final rounded = _currencyService.round2(amount);
    final record = TransactionRecord(
      id: _uuid.v4(),
      tenantId: auth.tenantId,
      initiatedByUserId: auth.userId,
      type: TransactionType.deposit,
      destinationAccountId: account.id,
      destinationAccountNumber: account.accountNumber,
      originalAmount: rounded,
      originalCurrency: account.currency,
      convertedAmount: rounded,
      destinationCurrency: account.currency,
      exchangeRate: 1.0,
      feeAmount: 0.0,
      feeCurrency: account.currency,
      totalDebited: 0.0,
      status: TransactionStatus.success,
      idempotencyKey: idempotencyKey,
      correlationId: correlationId,
      description: description?.trim().isEmpty ?? true
          ? 'Depósito a cuenta ${account.accountNumber}'
          : description!.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    final result = await _store.executeDeposit(
      tenantId: auth.tenantId,
      accountId: account.id,
      amount: rounded,
      record: record,
    );

    _webhookService.dispatchAsync(
      webhookUrl: tenant.config.webhookUrl,
      tenantId: tenant.id,
      tenantSlug: tenant.slug,
      eventType: 'deposit.completed',
      correlationId: correlationId,
      data: result.transaction.toJson(),
    );

    return result;
  }

  Future<FinancialExecutionResult> withdraw({
    required AuthContext auth,
    required String accountNumber,
    required double amount,
    required String idempotencyKey,
    required String correlationId,
    String? description,
  }) async {
    _validatePositiveAmount(amount);
    final tenant = await getCurrentTenant(auth);
    final account =
        await _store.findAccountByNumber(auth.tenantId, accountNumber);
    if (account == null) {
      throw const AppException(
        statusCode: 404,
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Cuenta no encontrada en esta institución',
      );
    }
    _ensureCanOperateOnAccount(auth, account);

    if (!account.status.isOperational) {
      throw AppException(
        statusCode: 422,
        code: 'ACCOUNT_INACTIVE',
        message: 'No se puede retirar de una cuenta ${account.status.value}',
      );
    }

    _currencyService.validateMaxLimit(
      tenant.config,
      amount: amount,
      currency: account.currency,
    );

    final rounded = _currencyService.round2(amount);
    final record = TransactionRecord(
      id: _uuid.v4(),
      tenantId: auth.tenantId,
      initiatedByUserId: auth.userId,
      type: TransactionType.withdrawal,
      sourceAccountId: account.id,
      sourceAccountNumber: account.accountNumber,
      originalAmount: rounded,
      originalCurrency: account.currency,
      convertedAmount: rounded,
      destinationCurrency: account.currency,
      exchangeRate: 1.0,
      feeAmount: 0.0,
      feeCurrency: account.currency,
      totalDebited: rounded,
      status: TransactionStatus.success,
      idempotencyKey: idempotencyKey,
      correlationId: correlationId,
      description: description?.trim().isEmpty ?? true
          ? 'Retiro de cuenta ${account.accountNumber}'
          : description!.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    try {
      final result = await _store.executeWithdrawal(
        tenantId: auth.tenantId,
        accountId: account.id,
        amount: rounded,
        record: record,
      );

      _webhookService.dispatchAsync(
        webhookUrl: tenant.config.webhookUrl,
        tenantId: tenant.id,
        tenantSlug: tenant.slug,
        eventType: 'withdrawal.completed',
        correlationId: correlationId,
        data: result.transaction.toJson(),
      );

      return result;
    } on AppException catch (e) {
      await _store.recordFailedTransaction(
        TransactionRecord(
          id: _uuid.v4(),
          tenantId: auth.tenantId,
          initiatedByUserId: auth.userId,
          type: TransactionType.withdrawal,
          sourceAccountId: account.id,
          sourceAccountNumber: account.accountNumber,
          originalAmount: rounded,
          originalCurrency: account.currency,
          convertedAmount: rounded,
          destinationCurrency: account.currency,
          exchangeRate: 1.0,
          feeAmount: 0.0,
          feeCurrency: account.currency,
          totalDebited: rounded,
          status: TransactionStatus.failed,
          failureReason: '${e.code}: ${e.message}',
          idempotencyKey: idempotencyKey,
          correlationId: correlationId,
          description: description,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      rethrow;
    }
  }

  Future<FinancialExecutionResult> transfer({
    required AuthContext auth,
    required String sourceAccountNumber,
    required String destinationAccountNumber,
    required double amount,
    required String idempotencyKey,
    required String correlationId,
    String? description,
  }) async {
    final quote = await quoteTransfer(
      auth: auth,
      sourceAccountNumber: sourceAccountNumber,
      destinationAccountNumber: destinationAccountNumber,
      amount: amount,
    );

    final tenant = await getCurrentTenant(auth);
    final source =
        (await _store.findAccountByNumber(auth.tenantId, sourceAccountNumber))!;
    final dest = (await _store.findAccountByNumber(
      auth.tenantId,
      destinationAccountNumber,
    ))!;

    final record = TransactionRecord(
      id: _uuid.v4(),
      tenantId: auth.tenantId,
      initiatedByUserId: auth.userId,
      type: TransactionType.transfer,
      sourceAccountId: source.id,
      sourceAccountNumber: source.accountNumber,
      destinationAccountId: dest.id,
      destinationAccountNumber: dest.accountNumber,
      originalAmount: quote.originalAmount,
      originalCurrency: quote.sourceCurrency,
      convertedAmount: quote.convertedAmount,
      destinationCurrency: quote.destinationCurrency,
      exchangeRate: quote.exchangeRate,
      feeAmount: quote.feeAmount,
      feeCurrency: quote.sourceCurrency,
      totalDebited: quote.totalDebitAmount,
      status: TransactionStatus.success,
      idempotencyKey: idempotencyKey,
      correlationId: correlationId,
      description: description?.trim().isEmpty ?? true
          ? 'Transferencia a ${dest.accountNumber} (${dest.ownerName})'
          : description!.trim(),
      createdAt: DateTime.now().toUtc(),
    );

    try {
      final result = await _store.executeTransfer(
        tenantId: auth.tenantId,
        sourceAccountId: source.id,
        destinationAccountId: dest.id,
        totalDebit: quote.totalDebitAmount,
        creditAmount: quote.convertedAmount,
        record: record,
      );

      _webhookService.dispatchAsync(
        webhookUrl: tenant.config.webhookUrl,
        tenantId: tenant.id,
        tenantSlug: tenant.slug,
        eventType: 'transfer.completed',
        correlationId: correlationId,
        data: result.transaction.toJson(),
      );

      return result;
    } on AppException catch (e) {
      await _store.recordFailedTransaction(
        TransactionRecord(
          id: _uuid.v4(),
          tenantId: auth.tenantId,
          initiatedByUserId: auth.userId,
          type: TransactionType.transfer,
          sourceAccountId: source.id,
          sourceAccountNumber: source.accountNumber,
          destinationAccountId: dest.id,
          destinationAccountNumber: dest.accountNumber,
          originalAmount: quote.originalAmount,
          originalCurrency: quote.sourceCurrency,
          convertedAmount: quote.convertedAmount,
          destinationCurrency: quote.destinationCurrency,
          exchangeRate: quote.exchangeRate,
          feeAmount: quote.feeAmount,
          feeCurrency: quote.sourceCurrency,
          totalDebited: quote.totalDebitAmount,
          status: TransactionStatus.failed,
          failureReason: '${e.code}: ${e.message}',
          idempotencyKey: idempotencyKey,
          correlationId: correlationId,
          description: description,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      rethrow;
    }
  }

  // ==================== HISTORY & AUDIT ====================

  Future<PaginatedResult<TransactionRecord>> listTransactions({
    required AuthContext auth,
    String? accountId,
    TransactionType? type,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    required int page,
    required int limit,
  }) {
    if (page < 1 || limit < 1 || limit > 100) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_PAGINATION',
        message: 'Parámetros de paginación inválidos (page >= 1, 1 <= limit <= 100)',
      );
    }

    return _store.listTransactions(
      tenantId: auth.tenantId,
      userIdFilter: auth.role == UserRole.administrador ? null : auth.userId,
      accountId: accountId,
      type: type,
      status: status,
      fromDate: fromDate,
      toDate: toDate,
      page: page,
      limit: limit,
    );
  }

  Future<PaginatedResult<AuditLog>> listAuditLogs({
    required AuthContext auth,
    required int page,
    required int limit,
  }) {
    if (page < 1 || limit < 1 || limit > 100) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_PAGINATION',
        message: 'Parámetros de paginación inválidos (page >= 1, 1 <= limit <= 100)',
      );
    }

    return _store.listAuditLogs(
      tenantId: auth.tenantId,
      page: page,
      limit: limit,
    );
  }

  // ==================== VALIDATION HELPERS ====================

  void _ensureCanOperateOnAccount(AuthContext auth, BankAccount account) {
    if (auth.role != UserRole.administrador &&
        account.ownerUserId != auth.userId) {
      throw const AppException(
        statusCode: 403,
        code: 'FORBIDDEN_ACCOUNT_OPERATION',
        message: 'Solo puede operar sobre cuentas de las cuales es titular',
      );
    }
  }

  void _validatePositiveAmount(double amount) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_AMOUNT',
        message: 'El monto debe ser estrictamente positivo',
      );
    }
  }

  void _validateTenantConfig(TenantConfig config) {
    if (config.maxTransactionLimit <= 0) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_CONFIG',
        message: 'El límite máximo por transacción debe ser mayor a cero',
      );
    }
    if (config.transferFeeValue < 0) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_CONFIG',
        message: 'La comisión no puede ser negativa',
      );
    }
    if (config.transferFeeType == FeeType.percentage &&
        config.transferFeeValue > 50) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_CONFIG',
        message: 'La comisión porcentual no puede superar el 50%',
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(config.baseCurrency.toUpperCase())) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_CONFIG',
        message: 'La moneda principal debe ser un código ISO de 3 letras',
      );
    }
    for (final entry in config.exchangeRates.entries) {
      if (entry.value <= 0) {
        throw AppException(
          statusCode: 400,
          code: 'INVALID_EXCHANGE_RATE',
          message: 'La tasa de cambio ${entry.key} debe ser mayor a cero',
        );
      }
    }
  }

  void _validatePasswordStrength(String password) {
    if (password.length < 6) {
      throw const AppException(
        statusCode: 400,
        code: 'WEAK_PASSWORD',
        message: 'La contraseña debe tener al menos 6 caracteres',
      );
    }
  }
}
