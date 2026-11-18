import 'dart:convert';

import 'package:bankos_backend/bankos_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();

  late InMemoryBankStore store;
  late InMemoryCacheStore cache;
  late List<WebhookEventRecord> dispatchedWebhooks;
  late BankOsApp app;

  Future<Response> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
    String? idempotencyKey,
    String? correlationId,
    String clientIp = '10.0.0.1',
  }) {
    final headers = <String, String>{
      'content-type': 'application/json',
      'x-forwarded-for': clientIp,
      if (token != null) 'authorization': 'Bearer $token',
      if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
      if (correlationId != null) 'x-correlation-id': correlationId,
    };
    final req = Request(
      method,
      Uri.parse('http://localhost:8080$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return Future.sync(() => app.handler(req));
  }

  Future<Map<String, dynamic>> decodeBody(Response res) async {
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  Future<String> loginAs(
    String tenantSlug,
    String email,
    String password, {
    String clientIp = '10.0.0.1',
  }) async {
    final res = await send(
      'POST',
      '/api/v1/auth/login',
      clientIp: clientIp,
      body: {
        'tenant_slug': tenantSlug,
        'email': email,
        'password': password,
      },
    );
    expect(res.statusCode, 200);
    final json = await decodeBody(res);
    return (json['data'] as Map<String, dynamic>)['access_token'] as String;
  }

  setUp(() async {
    store = InMemoryBankStore();
    cache = InMemoryCacheStore();
    dispatchedWebhooks = [];

    final mockHttp = MockClient((request) async {
      return http.Response('{"ok":true}', 200);
    });

    final webhookService = WebhookService(
      signingSecret: 'test-webhook-secret',
      httpClient: mockHttp,
      onDispatched: dispatchedWebhooks.add,
    );

    final config = EnvConfig.fromEnvironment({
      'JWT_SECRET': 'test-jwt-secret-key',
      'AUTH_RATE_LIMIT_MAX': '5',
      'AUTH_RATE_LIMIT_WINDOW_SECONDS': '60',
      'TX_RATE_LIMIT_MAX': '20',
      'TX_RATE_LIMIT_WINDOW_SECONDS': '60',
    });

    await store.initialize();
    await seedDemoTenants(
      store,
      defaultWebhookUrl: 'https://hooks.bankos.test/events',
    );

    app = BankOsApp(
      config: config,
      store: store,
      cache: cache,
      webhookService: webhookService,
      enableRequestLogging: false,
    );
  });

  group('BankOS API v1 - Core Multitenant Banking Flows', () {
    test('health endpoint returns healthy status and X-Correlation-ID', () async {
      const cid = 'corr-health-check-001';
      final res = await send('GET', '/api/v1/health', correlationId: cid);
      expect(res.statusCode, 200);
      expect(res.headers['x-correlation-id'], cid);

      final body = await decodeBody(res);
      expect(body['success'], isTrue);
      expect(body['code'], 'SERVICE_HEALTHY');
      expect((body['meta'] as Map)['correlation_id'], cid);
    });

    test('strict tenant isolation: two tenants operate in parallel without data leakage',
        () async {
      final anaToken = await loginAs(
        'banco-andes',
        'ana@andes.bank',
        'Cliente123!',
        clientIp: '10.0.0.10',
      );
      final mariaToken = await loginAs(
        'cooperativa-sol',
        'maria@sol.coop',
        'Cliente123!',
        clientIp: '10.0.0.11',
      );

      // Ana cannot log in under cooperativa-sol
      final wrongTenantLogin = await send(
        'POST',
        '/api/v1/auth/login',
        clientIp: '10.0.0.12',
        body: {
          'tenant_slug': 'cooperativa-sol',
          'email': 'ana@andes.bank',
          'password': 'Cliente123!',
        },
      );
      expect(wrongTenantLogin.statusCode, 401);

      // Ana sees ONLY her accounts in banco-andes
      final anaAccountsRes = await send('GET', '/api/v1/accounts', token: anaToken);
      final anaAccounts =
          ((await decodeBody(anaAccountsRes))['data']['accounts'] as List);
      expect(anaAccounts.length, 2);
      expect(
        anaAccounts.every((a) => (a['account_number'] as String).startsWith('AND-')),
        isTrue,
      );

      // Maria sees ONLY her account in cooperativa-sol
      final mariaAccountsRes =
          await send('GET', '/api/v1/accounts', token: mariaToken);
      final mariaAccounts =
          ((await decodeBody(mariaAccountsRes))['data']['accounts'] as List);
      expect(mariaAccounts.length, 1);
      expect(mariaAccounts.first['account_number'], 'SOL-USD-1001');

      // Ana CANNOT lookup or transfer to Maria's account (returns 404, never leaks existence)
      final crossLookup = await send(
        'GET',
        '/api/v1/accounts/lookup/SOL-USD-1001',
        token: anaToken,
      );
      expect(crossLookup.statusCode, 404);

      final crossTransfer = await send(
        'POST',
        '/api/v1/transactions/transfer',
        token: anaToken,
        idempotencyKey: uuid.v4(),
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'SOL-USD-1001',
          'amount': 50,
        },
      );
      expect(crossTransfer.statusCode, 404);
    });

    test('multicurrency transfer applies tenant static FX rate, configured fee, and fires webhook',
        () async {
      final anaToken = await loginAs(
        'banco-andes',
        'ana@andes.bank',
        'Cliente123!',
      );
      final carlosToken = await loginAs(
        'banco-andes',
        'carlos@andes.bank',
        'Cliente123!',
      );

      // Step 1: Quote USD -> COP transfer
      final quoteRes = await send(
        'POST',
        '/api/v1/transactions/quote',
        token: anaToken,
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'AND-COP-2001',
          'amount': 100.0,
        },
      );
      expect(quoteRes.statusCode, 200);
      final quote = (await decodeBody(quoteRes))['data'] as Map<String, dynamic>;
      expect(quote['original_amount'], 100.0);
      expect(quote['fee_amount'], 1.5); // 1.5% configured on banco-andes
      expect(quote['total_debit_amount'], 101.5);
      expect(quote['exchange_rate'], 4000.0);
      expect(quote['converted_amount'], 400000.0);
      expect(quote['has_currency_conversion'], isTrue);

      // Step 2: Execute transfer with mandatory Idempotency-Key and X-Correlation-ID
      final idemKey = uuid.v4();
      const correlationId = 'corr-fx-transfer-001';
      final txRes = await send(
        'POST',
        '/api/v1/transactions/transfer',
        token: anaToken,
        idempotencyKey: idemKey,
        correlationId: correlationId,
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'AND-COP-2001',
          'amount': 100.0,
          'description': 'Pago servicios internacionales',
        },
      );
      expect(txRes.statusCode, 201);
      expect(txRes.headers['x-correlation-id'], correlationId);
      expect(txRes.headers['x-idempotency-replayed'], 'false');

      final txBody = await decodeBody(txRes);
      final tx = txBody['data']['transaction'] as Map<String, dynamic>;
      expect(tx['original_amount'], 100.0);
      expect(tx['fee_amount'], 1.5);
      expect(tx['total_debited'], 101.5);
      expect(tx['exchange_rate'], 4000.0);
      expect(tx['converted_amount'], 400000.0);
      expect(tx['idempotency_key'], idemKey);
      expect(tx['correlation_id'], correlationId);
      expect(tx['has_fee'], isTrue);
      expect(tx['has_currency_conversion'], isTrue);

      // Verify exact balances
      final anaAcc = await decodeBody(
        await send('GET', '/api/v1/accounts/AND-USD-1001', token: anaToken),
      );
      expect(anaAcc['data']['balance'], 4898.5); // 5000 - 101.5

      final carlosAcc = await decodeBody(
        await send('GET', '/api/v1/accounts/AND-COP-2001', token: carlosToken),
      );
      expect(carlosAcc['data']['balance'], 3600000.0); // 3,200,000 + 400,000

      // Verify async webhook was triggered
      expect(dispatchedWebhooks, isNotEmpty);
      expect(dispatchedWebhooks.last.eventType, 'transfer.completed');
      expect(dispatchedWebhooks.last.correlationId, correlationId);
    });

    test('idempotency: retry with same Idempotency-Key returns exact response without double charging',
        () async {
      final anaToken = await loginAs(
        'banco-andes',
        'ana@andes.bank',
        'Cliente123!',
      );
      final idemKey = uuid.v4();

      // Missing key is rejected
      final missingRes = await send(
        'POST',
        '/api/v1/transactions/transfer',
        token: anaToken,
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'AND-COP-2001',
          'amount': 200.0,
        },
      );
      expect(missingRes.statusCode, 400);
      expect((await decodeBody(missingRes))['code'], 'IDEMPOTENCY_KEY_REQUIRED');

      // First attempt succeeds
      final firstRes = await send(
        'POST',
        '/api/v1/transactions/transfer',
        token: anaToken,
        idempotencyKey: idemKey,
        correlationId: 'corr-retry-1',
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'AND-COP-2001',
          'amount': 200.0,
        },
      );
      expect(firstRes.statusCode, 201);
      final firstRawBody = await firstRes.readAsString();

      // Second attempt (simulated network retry) with EXACT same key replays exact response
      final retryRes = await send(
        'POST',
        '/api/v1/transactions/transfer',
        token: anaToken,
        idempotencyKey: idemKey,
        correlationId: 'corr-retry-1',
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'AND-COP-2001',
          'amount': 200.0,
        },
      );
      expect(retryRes.statusCode, 201);
      expect(retryRes.headers['x-idempotency-replayed'], 'true');
      final retryRawBody = await retryRes.readAsString();
      expect(retryRawBody, firstRawBody);

      // Balance was debited ONCE: 5000 - (200 + 3.00 fee) = 4797.00
      final anaAcc = await decodeBody(
        await send('GET', '/api/v1/accounts/AND-USD-1001', token: anaToken),
      );
      expect(anaAcc['data']['balance'], 4797.0);
    });

    test('idempotency: concurrent in-progress key responds 409 Conflict', () async {
      final anaToken = await loginAs(
        'banco-andes',
        'ana@andes.bank',
        'Cliente123!',
      );
      final auth = app.jwtService.verify(anaToken);
      final idemKey = uuid.v4();

      // Pre-seed IN_PROGRESS lock in cache simulating concurrent flight
      await cache.setIfNotExists(
        'idem:${auth.tenantId}:${auth.userId}:$idemKey',
        jsonEncode({'state': 'IN_PROGRESS'}),
        86400,
      );

      final res = await send(
        'POST',
        '/api/v1/transactions/deposit',
        token: anaToken,
        idempotencyKey: idemKey,
        body: {
          'account_number': 'AND-USD-1001',
          'amount': 100.0,
        },
      );
      expect(res.statusCode, 409);
      expect((await decodeBody(res))['code'], 'TRANSACTION_IN_PROGRESS');
    });

    test('RBAC, soft delete, and immutable audit log', () async {
      final adminToken = await loginAs(
        'banco-andes',
        'admin@andes.bank',
        'Admin123!',
      );
      final anaToken = await loginAs(
        'banco-andes',
        'ana@andes.bank',
        'Cliente123!',
      );

      // Client cannot update tenant config or view audit logs
      final forbiddenConfig = await send(
        'PATCH',
        '/api/v1/tenants/current/config',
        token: anaToken,
        body: {'max_transaction_limit': 99999999},
      );
      expect(forbiddenConfig.statusCode, 403);

      final forbiddenAudit = await send(
        'GET',
        '/api/v1/audit-logs',
        token: anaToken,
      );
      expect(forbiddenAudit.statusCode, 403);

      // Admin updates config
      final updateConfigRes = await send(
        'PATCH',
        '/api/v1/tenants/current/config',
        token: adminToken,
        body: {'transfer_fee_value': 2.0},
      );
      expect(updateConfigRes.statusCode, 200);

      // Admin soft-deletes Ana's USD account
      final accDetail = await decodeBody(
        await send('GET', '/api/v1/accounts/AND-USD-1001', token: adminToken),
      );
      final accId = accDetail['data']['id'] as String;

      final softDeleteRes = await send(
        'DELETE',
        '/api/v1/accounts/$accId?status=bloqueada',
        token: adminToken,
      );
      expect(softDeleteRes.statusCode, 200);
      expect((await decodeBody(softDeleteRes))['data']['status'], 'bloqueada');

      // Operations on deactivated/blocked account are strictly forbidden
      final blockedDeposit = await send(
        'POST',
        '/api/v1/transactions/deposit',
        token: anaToken,
        idempotencyKey: uuid.v4(),
        body: {'account_number': 'AND-USD-1001', 'amount': 50.0},
      );
      expect(blockedDeposit.statusCode, 422);
      expect((await decodeBody(blockedDeposit))['code'], 'ACCOUNT_INACTIVE');

      // Audit logs captured both admin actions
      final auditRes = await send(
        'GET',
        '/api/v1/audit-logs?page=1&limit=10',
        token: adminToken,
      );
      expect(auditRes.statusCode, 200);
      final logs = (await decodeBody(auditRes))['data']['audit_logs'] as List;
      final actions = logs.map((e) => e['action']).toList();
      expect(actions, contains('TENANT_CONFIG_UPDATED'));
      expect(actions, contains('ACCOUNT_DEACTIVATED'));
    });

    test('rate limiting blocks brute force auth requests with 429', () async {
      // Configured max is 5 per 60s
      for (var i = 0; i < 5; i++) {
        final res = await send(
          'POST',
          '/api/v1/auth/login',
          clientIp: '192.168.1.99',
          body: {
            'tenant_slug': 'banco-andes',
            'email': 'ana@andes.bank',
            'password': 'WrongPassword!',
          },
        );
        expect(res.statusCode, 401);
      }

      final blocked = await send(
        'POST',
        '/api/v1/auth/login',
        clientIp: '192.168.1.99',
        body: {
          'tenant_slug': 'banco-andes',
          'email': 'ana@andes.bank',
          'password': 'WrongPassword!',
        },
      );
      expect(blocked.statusCode, 429);
      expect(blocked.headers['retry-after'], isNotNull);
    });

    test('paginated transaction history with type filter and tenant onboarding',
        () async {
      final anaToken = await loginAs(
        'banco-andes',
        'ana@andes.bank',
        'Cliente123!',
      );

      // Perform 1 deposit, 1 withdrawal, 1 transfer
      await send(
        'POST',
        '/api/v1/transactions/deposit',
        token: anaToken,
        idempotencyKey: uuid.v4(),
        body: {'account_number': 'AND-USD-1001', 'amount': 250.0},
      );
      await send(
        'POST',
        '/api/v1/transactions/withdraw',
        token: anaToken,
        idempotencyKey: uuid.v4(),
        body: {'account_number': 'AND-USD-1001', 'amount': 50.0},
      );
      await send(
        'POST',
        '/api/v1/transactions/transfer',
        token: anaToken,
        idempotencyKey: uuid.v4(),
        body: {
          'source_account_number': 'AND-USD-1001',
          'destination_account_number': 'AND-COP-2001',
          'amount': 25.0,
        },
      );

      // Page 1, limit 2
      final page1Res = await send(
        'GET',
        '/api/v1/transactions?page=1&limit=2',
        token: anaToken,
      );
      expect(page1Res.statusCode, 200);
      final page1 = await decodeBody(page1Res);
      expect((page1['data']['transactions'] as List).length, 2);
      expect(page1['meta']['pagination']['total'], 3);
      expect(page1['meta']['pagination']['has_next'], isTrue);

      // Filter by type=deposit
      final depRes = await send(
        'GET',
        '/api/v1/transactions?page=1&limit=10&type=deposit',
        token: anaToken,
      );
      final deps = (await decodeBody(depRes))['data']['transactions'] as List;
      expect(deps.length, 1);
      expect(deps.first['type'], 'deposit');

      // Onboard a 3rd new tenant via API
      final newTenantRes = await send(
        'POST',
        '/api/v1/tenants',
        body: {
          'name': 'Fintech Caribe',
          'slug': 'fintech-caribe',
          'config': {
            'max_transaction_limit': 5000,
            'transfer_fee_type': 'fixed',
            'transfer_fee_value': 1.25,
            'base_currency': 'USD',
            'exchange_rates': {'USD_COP': 4050.0},
          },
          'admin': {
            'email': 'ceo@caribe.fin',
            'full_name': 'Sofía Morales',
            'password': 'SuperPassword123',
          },
        },
      );
      expect(newTenantRes.statusCode, 201);
      final newTenantBody = await decodeBody(newTenantRes);
      expect(newTenantBody['data']['tenant']['slug'], 'fintech-caribe');
      expect(newTenantBody['data']['access_token'], isNotEmpty);
    });
  });
}
