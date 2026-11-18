import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../cache/cache_store.dart';
import '../config/env_config.dart';
import '../db/bank_store.dart';
import '../middleware/middlewares.dart';
import '../models/api_response.dart';
import '../models/domain_models.dart';
import '../security/jwt_service.dart';
import '../services/banking_service.dart';
import '../services/idempotency_service.dart';
import '../services/rate_limiter_service.dart';

class ApiV1Router {
  ApiV1Router({
    required EnvConfig config,
    required BankStore store,
    required CacheStore cache,
    required JwtService jwtService,
    required BankingService bankingService,
    required IdempotencyService idempotencyService,
    required RateLimiterService rateLimiter,
  })  : _config = config,
        _store = store,
        _cache = cache,
        _jwtService = jwtService,
        _bankingService = bankingService,
        _idempotencyService = idempotencyService,
        _rateLimiter = rateLimiter;

  final EnvConfig _config;
  final BankStore _store;
  final CacheStore _cache;
  final JwtService _jwtService;
  final BankingService _bankingService;
  final IdempotencyService _idempotencyService;
  final RateLimiterService _rateLimiter;

  Router get router {
    final r = Router();

    // Health
    r.get('/api/v1/health', _health);

    // Tenants
    r.post('/api/v1/tenants', _registerTenant);
    r.get('/api/v1/tenants/current', _getCurrentTenant);
    r.patch('/api/v1/tenants/current/config', _updateTenantConfig);

    // Auth & Users
    r.post('/api/v1/auth/login', _login);
    r.post('/api/v1/auth/register', _registerUser);
    r.get('/api/v1/auth/me', _me);
    r.get('/api/v1/users', _listUsers);

    // Accounts
    r.post('/api/v1/accounts', _createAccount);
    r.get('/api/v1/accounts', _listAccounts);
    r.get('/api/v1/accounts/lookup/<accountNumber>', _lookupAccount);
    r.get('/api/v1/accounts/<accountNumber>', _getAccount);
    r.delete('/api/v1/accounts/<accountId>', _softDeleteAccount);
    r.patch('/api/v1/accounts/<accountId>/status', _updateAccountStatus);

    // Financial Operations (Idempotent + Rate Limited)
    r.post('/api/v1/transactions/quote', _quoteTransfer);
    r.post('/api/v1/transactions/deposit', _deposit);
    r.post('/api/v1/transactions/withdraw', _withdraw);
    r.post('/api/v1/transactions/transfer', _transfer);
    r.get('/api/v1/transactions', _listTransactions);

    // Immutable Audit Logs (Admin Only)
    r.get('/api/v1/audit-logs', _listAuditLogs);

    // 404 fallback
    r.all('/<ignored|.*>', (Request request) {
      return ApiResponse.error(
        statusCode: 404,
        code: 'ROUTE_NOT_FOUND',
        message: 'Endpoint no encontrado: ${request.method} /${request.url.path}',
        correlationId: getCorrelationId(request),
      );
    });

    return r;
  }

  // ==================== HEALTH ====================

  Future<Response> _health(Request request) async {
    final dbOk = await _store.ping();
    final cacheOk = await _cache.ping();
    final healthy = dbOk && cacheOk;

    return ApiResponse.ok(
      statusCode: healthy ? 200 : 503,
      code: healthy ? 'SERVICE_HEALTHY' : 'SERVICE_DEGRADED',
      message: healthy
          ? 'BankOS API v1 operativa'
          : 'Algunos servicios dependientes no responden',
      correlationId: getCorrelationId(request),
      data: {
        'service': 'bankos-api',
        'version': '1.0.0',
        'api_version': 'v1',
        'dependencies': {
          'postgres': dbOk ? 'up' : 'down',
          'redis': cacheOk ? 'up' : 'down',
        },
      },
    );
  }

  // ==================== TENANTS ====================

  Future<Response> _registerTenant(Request request) async {
    final correlationId = getCorrelationId(request);
    final body = await readJsonBody(request);

    final name = requireString(body, 'name');
    final slug = requireString(body, 'slug');

    final configRaw = body['config'];
    final configMap = configRaw is Map
        ? configRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, Object?>{};

    final config = TenantConfig(
      maxTransactionLimit:
          ((configMap['max_transaction_limit'] as num?) ?? 10000000).toDouble(),
      transferFeeType: FeeType.fromString(
        (configMap['transfer_fee_type'] as String?) ?? 'percentage',
      ),
      transferFeeValue:
          ((configMap['transfer_fee_value'] as num?) ?? 1.0).toDouble(),
      baseCurrency: ((configMap['base_currency'] as String?) ?? 'COP')
          .toUpperCase(),
      exchangeRates: _parseExchangeRates(configMap['exchange_rates']),
      webhookUrl: configMap['webhook_url'] as String?,
    );

    final adminRaw = body['admin'];
    if (adminRaw is! Map) {
      throw const AppException(
        statusCode: 400,
        code: 'VALIDATION_ERROR',
        message:
            'El objeto "admin" (email, full_name, password) es obligatorio al crear un tenant',
      );
    }
    final adminMap = adminRaw.map((k, v) => MapEntry(k.toString(), v));

    final result = await _bankingService.registerTenant(
      name: name,
      slug: slug,
      config: config,
      adminEmail: requireString(adminMap, 'email'),
      adminFullName: requireString(adminMap, 'full_name'),
      adminPassword: requireString(adminMap, 'password'),
      correlationId: correlationId,
    );

    return ApiResponse.ok(
      statusCode: 201,
      code: 'TENANT_CREATED',
      message: 'Institución financiera registrada exitosamente',
      correlationId: correlationId,
      data: result.toJson(),
    );
  }

  Future<Response> _getCurrentTenant(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final tenant = await _bankingService.getCurrentTenant(auth);
    return ApiResponse.ok(
      code: 'TENANT_FETCHED',
      message: 'Configuración de la institución obtenida',
      correlationId: getCorrelationId(request),
      data: tenant.toJson(),
    );
  }

  Future<Response> _updateTenantConfig(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final correlationId = getCorrelationId(request);
    final body = await readJsonBody(request);
    final current = await _bankingService.getCurrentTenant(auth);

    final updatedConfig = current.config.copyWith(
      maxTransactionLimit: body['max_transaction_limit'] != null
          ? requireDouble(body, 'max_transaction_limit')
          : null,
      transferFeeType: body['transfer_fee_type'] is String
          ? FeeType.fromString(body['transfer_fee_type'] as String)
          : null,
      transferFeeValue: body['transfer_fee_value'] != null
          ? requireDouble(body, 'transfer_fee_value')
          : null,
      baseCurrency: body['base_currency'] is String
          ? (body['base_currency'] as String).trim().toUpperCase()
          : null,
      exchangeRates: body.containsKey('exchange_rates')
          ? _parseExchangeRates(body['exchange_rates'])
          : null,
      webhookUrl: body['webhook_url'] as String?,
      clearWebhookUrl:
          body.containsKey('webhook_url') && body['webhook_url'] == null,
    );

    final updated = await _bankingService.updateTenantConfig(
      auth: auth,
      newConfig: updatedConfig,
      correlationId: correlationId,
    );

    return ApiResponse.ok(
      code: 'TENANT_CONFIG_UPDATED',
      message: 'Configuración del tenant actualizada y auditada',
      correlationId: correlationId,
      data: updated.toJson(),
    );
  }

  // ==================== AUTH & USERS ====================

  Future<Response> _login(Request request) async {
    final correlationId = getCorrelationId(request);
    final body = await readJsonBody(request);
    final tenantSlug = requireString(body, 'tenant_slug');
    final email = requireString(body, 'email');
    final password = requireString(body, 'password');

    final rl = await _rateLimiter.check(
      scope: 'auth',
      clientIp: extractClientIp(request),
      accountKey: '$tenantSlug:$email',
      maxRequests: _config.authRateLimitMax,
      windowSeconds: _config.authRateLimitWindowSeconds,
    );

    final result = await _bankingService.login(
      tenantSlug: tenantSlug,
      email: email,
      password: password,
    );

    return ApiResponse.ok(
      code: 'LOGIN_SUCCESS',
      message: 'Autenticación exitosa',
      correlationId: correlationId,
      data: result.toJson(),
      extraHeaders: rl.toHeaders(),
    );
  }

  Future<Response> _registerUser(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final correlationId = getCorrelationId(request);
    final body = await readJsonBody(request);
    final roleRaw = (body['role'] as String?) ?? 'cliente';

    final user = await _bankingService.createUserInTenant(
      auth: auth,
      email: requireString(body, 'email'),
      fullName: requireString(body, 'full_name'),
      password: requireString(body, 'password'),
      role: UserRole.fromString(roleRaw),
      correlationId: correlationId,
    );

    return ApiResponse.ok(
      statusCode: 201,
      code: 'USER_CREATED',
      message: 'Usuario creado exitosamente dentro del tenant',
      correlationId: correlationId,
      data: user.toSafeJson(),
    );
  }

  Future<Response> _me(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final user = await _bankingService.getUserProfile(auth);
    final tenant = await _bankingService.getCurrentTenant(auth);

    return ApiResponse.ok(
      code: 'PROFILE_FETCHED',
      message: 'Sesión activa verificada',
      correlationId: getCorrelationId(request),
      data: {
        'user': user.toSafeJson(),
        'tenant': tenant.toJson(),
      },
    );
  }

  Future<Response> _listUsers(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final users = await _bankingService.listUsers(auth);
    return ApiResponse.ok(
      code: 'USERS_LISTED',
      message: 'Usuarios del tenant obtenidos',
      correlationId: getCorrelationId(request),
      data: {'users': users.map((u) => u.toSafeJson()).toList()},
    );
  }

  // ==================== ACCOUNTS ====================

  Future<Response> _createAccount(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final correlationId = getCorrelationId(request);
    final body = await readJsonBody(request);

    final account = await _bankingService.createAccount(
      auth: auth,
      ownerUserId: requireString(body, 'owner_user_id'),
      currency: requireString(body, 'currency'),
      initialBalance: body['initial_balance'] != null
          ? requireDouble(body, 'initial_balance')
          : 0.0,
      customAccountNumber: body['account_number'] as String?,
      correlationId: correlationId,
    );

    return ApiResponse.ok(
      statusCode: 201,
      code: 'ACCOUNT_CREATED',
      message: 'Cuenta bancaria creada exitosamente',
      correlationId: correlationId,
      data: account.toJson(),
    );
  }

  Future<Response> _listAccounts(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final accounts = await _bankingService.listAccounts(auth);

    return ApiResponse.ok(
      code: 'ACCOUNTS_LISTED',
      message: 'Cuentas obtenidas exitosamente',
      correlationId: getCorrelationId(request),
      data: {'accounts': accounts.map((a) => a.toJson()).toList()},
    );
  }

  Future<Response> _lookupAccount(Request request, String accountNumber) async {
    final auth = authenticateRequest(request, _jwtService);
    final account = await _bankingService.lookupDestinationAccount(
      auth: auth,
      accountNumber: Uri.decodeComponent(accountNumber),
    );

    return ApiResponse.ok(
      code: 'ACCOUNT_FOUND',
      message: 'Cuenta destino localizada',
      correlationId: getCorrelationId(request),
      data: account.toLookupJson(),
    );
  }

  Future<Response> _getAccount(Request request, String accountNumber) async {
    final auth = authenticateRequest(request, _jwtService);
    final account = await _bankingService.getAccountByNumber(
      auth: auth,
      accountNumber: Uri.decodeComponent(accountNumber),
    );

    return ApiResponse.ok(
      code: 'ACCOUNT_FETCHED',
      message: 'Detalle de cuenta obtenido',
      correlationId: getCorrelationId(request),
      data: account.toJson(),
    );
  }

  Future<Response> _softDeleteAccount(Request request, String accountId) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final statusParam = request.url.queryParameters['status'] ?? 'inactiva';
    final targetStatus = AccountStatus.fromString(statusParam);
    if (targetStatus == AccountStatus.activa) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_SOFT_DELETE_STATUS',
        message: 'Para borrado lógico use estado "inactiva" o "bloqueada"',
      );
    }

    final correlationId = getCorrelationId(request);
    final updated = await _bankingService.updateAccountStatus(
      auth: auth,
      accountId: accountId,
      newStatus: targetStatus,
      correlationId: correlationId,
    );

    return ApiResponse.ok(
      code: 'ACCOUNT_DEACTIVATED',
      message:
          'Cuenta desactivada mediante borrado lógico (${updated.status.value})',
      correlationId: correlationId,
      data: updated.toJson(),
    );
  }

  Future<Response> _updateAccountStatus(
    Request request,
    String accountId,
  ) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final correlationId = getCorrelationId(request);
    final body = await readJsonBody(request);
    final newStatus = AccountStatus.fromString(requireString(body, 'status'));

    final updated = await _bankingService.updateAccountStatus(
      auth: auth,
      accountId: accountId,
      newStatus: newStatus,
      correlationId: correlationId,
    );

    return ApiResponse.ok(
      code: 'ACCOUNT_STATUS_UPDATED',
      message: 'Estado de cuenta actualizado a ${updated.status.value}',
      correlationId: correlationId,
      data: updated.toJson(),
    );
  }

  // ==================== TRANSACTIONS ====================

  Future<Response> _quoteTransfer(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final body = await readJsonBody(request);

    final quote = await _bankingService.quoteTransfer(
      auth: auth,
      sourceAccountNumber: requireString(body, 'source_account_number'),
      destinationAccountNumber:
          requireString(body, 'destination_account_number'),
      amount: requireDouble(body, 'amount'),
    );

    return ApiResponse.ok(
      code: 'TRANSFER_QUOTED',
      message: 'Cotización de transferencia calculada',
      correlationId: getCorrelationId(request),
      data: quote.toJson(),
    );
  }

  Future<Response> _deposit(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final correlationId = getCorrelationId(request);

    final rl = await _rateLimiter.check(
      scope: 'transactions',
      clientIp: extractClientIp(request),
      accountKey: '${auth.tenantId}:${auth.userId}',
      maxRequests: _config.txRateLimitMax,
      windowSeconds: _config.txRateLimitWindowSeconds,
    );

    final body = await readJsonBody(request);
    final accountNumber = requireString(body, 'account_number');
    final amount = requireDouble(body, 'amount');
    final description = body['description'] as String?;

    return _idempotencyService.execute(
      tenantId: auth.tenantId,
      userId: auth.userId,
      rawKey: request.headers['idempotency-key'],
      correlationId: correlationId,
      operation: (validatedKey) async {
        final result = await _bankingService.deposit(
          auth: auth,
          accountNumber: accountNumber,
          amount: amount,
          idempotencyKey: validatedKey,
          correlationId: correlationId,
          description: description,
        );

        return ApiResponse.ok(
          statusCode: 201,
          code: 'DEPOSIT_COMPLETED',
          message: 'Depósito abonado exitosamente',
          correlationId: correlationId,
          data: {
            'transaction': result.transaction.toJson(),
            'account': result.destinationAccount?.toJson(),
          },
          extraHeaders: rl.toHeaders(),
        );
      },
    );
  }

  Future<Response> _withdraw(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final correlationId = getCorrelationId(request);

    final rl = await _rateLimiter.check(
      scope: 'transactions',
      clientIp: extractClientIp(request),
      accountKey: '${auth.tenantId}:${auth.userId}',
      maxRequests: _config.txRateLimitMax,
      windowSeconds: _config.txRateLimitWindowSeconds,
    );

    final body = await readJsonBody(request);
    final accountNumber = requireString(body, 'account_number');
    final amount = requireDouble(body, 'amount');
    final description = body['description'] as String?;

    return _idempotencyService.execute(
      tenantId: auth.tenantId,
      userId: auth.userId,
      rawKey: request.headers['idempotency-key'],
      correlationId: correlationId,
      operation: (validatedKey) async {
        final result = await _bankingService.withdraw(
          auth: auth,
          accountNumber: accountNumber,
          amount: amount,
          idempotencyKey: validatedKey,
          correlationId: correlationId,
          description: description,
        );

        return ApiResponse.ok(
          statusCode: 201,
          code: 'WITHDRAWAL_COMPLETED',
          message: 'Retiro procesado exitosamente',
          correlationId: correlationId,
          data: {
            'transaction': result.transaction.toJson(),
            'account': result.sourceAccount?.toJson(),
          },
          extraHeaders: rl.toHeaders(),
        );
      },
    );
  }

  Future<Response> _transfer(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final correlationId = getCorrelationId(request);

    final rl = await _rateLimiter.check(
      scope: 'transactions',
      clientIp: extractClientIp(request),
      accountKey: '${auth.tenantId}:${auth.userId}',
      maxRequests: _config.txRateLimitMax,
      windowSeconds: _config.txRateLimitWindowSeconds,
    );

    final body = await readJsonBody(request);
    final sourceAccountNumber = requireString(body, 'source_account_number');
    final destinationAccountNumber =
        requireString(body, 'destination_account_number');
    final amount = requireDouble(body, 'amount');
    final description = body['description'] as String?;

    return _idempotencyService.execute(
      tenantId: auth.tenantId,
      userId: auth.userId,
      rawKey: request.headers['idempotency-key'],
      correlationId: correlationId,
      operation: (validatedKey) async {
        final result = await _bankingService.transfer(
          auth: auth,
          sourceAccountNumber: sourceAccountNumber,
          destinationAccountNumber: destinationAccountNumber,
          amount: amount,
          idempotencyKey: validatedKey,
          correlationId: correlationId,
          description: description,
        );

        return ApiResponse.ok(
          statusCode: 201,
          code: 'TRANSFER_COMPLETED',
          message: 'Transferencia ejecutada exitosamente',
          correlationId: correlationId,
          data: {
            'transaction': result.transaction.toJson(),
            'source_account': result.sourceAccount?.toJson(),
            'destination_account': result.destinationAccount?.toLookupJson(),
          },
          extraHeaders: rl.toHeaders(),
        );
      },
    );
  }

  Future<Response> _listTransactions(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    final q = request.url.queryParameters;

    final page = int.tryParse(q['page'] ?? '1');
    final limit = int.tryParse(q['limit'] ?? '20');
    if (page == null || limit == null) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_PAGINATION',
        message: 'Los parámetros page y limit deben ser números enteros',
      );
    }

    final typeRaw = q['type'];
    final statusRaw = q['status'];
    final fromRaw = q['from_date'];
    final toRaw = q['to_date'];

    final result = await _bankingService.listTransactions(
      auth: auth,
      accountId: q['account_id'],
      type: (typeRaw != null && typeRaw.isNotEmpty)
          ? TransactionType.fromString(typeRaw)
          : null,
      status: (statusRaw != null && statusRaw.isNotEmpty)
          ? TransactionStatus.fromString(statusRaw)
          : null,
      fromDate: (fromRaw != null && fromRaw.isNotEmpty)
          ? DateTime.parse(fromRaw).toUtc()
          : null,
      toDate: (toRaw != null && toRaw.isNotEmpty)
          ? DateTime.parse(toRaw).toUtc()
          : null,
      page: page,
      limit: limit,
    );

    return ApiResponse.ok(
      code: 'TRANSACTIONS_LISTED',
      message: 'Historial de transacciones obtenido',
      correlationId: getCorrelationId(request),
      data: {
        'transactions': result.items.map((t) => t.toJson()).toList(),
      },
      pagination: result.paginationMeta(),
    );
  }

  // ==================== AUDIT LOGS ====================

  Future<Response> _listAuditLogs(Request request) async {
    final auth = authenticateRequest(request, _jwtService);
    requireRole(auth, UserRole.administrador);

    final q = request.url.queryParameters;
    final page = int.tryParse(q['page'] ?? '1') ?? 1;
    final limit = int.tryParse(q['limit'] ?? '20') ?? 20;

    final result = await _bankingService.listAuditLogs(
      auth: auth,
      page: page,
      limit: limit,
    );

    return ApiResponse.ok(
      code: 'AUDIT_LOGS_LISTED',
      message: 'Registro de auditoría inmutable obtenido',
      correlationId: getCorrelationId(request),
      data: {
        'audit_logs': result.items.map((l) => l.toJson()).toList(),
      },
      pagination: result.paginationMeta(),
    );
  }

  Map<String, double> _parseExchangeRates(Object? raw) {
    final result = <String, double>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim().toUpperCase();
        final value = entry.value;
        if (value is num) {
          result[key] = value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) result[key] = parsed;
        }
      }
    }
    return result;
  }
}
