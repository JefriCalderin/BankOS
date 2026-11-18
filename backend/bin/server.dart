import 'dart:convert';
import 'dart:io';

import 'package:bankos_backend/bankos_backend.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final config = EnvConfig.fromEnvironment();

  late final BankStore store;
  late final CacheStore cache;

  if (config.useInMemoryFallback) {
    print('[BankOS] Running in IN-MEMORY mode (USE_IN_MEMORY=true)');
    store = InMemoryBankStore();
    cache = InMemoryCacheStore();
  } else {
    store = await _connectPostgresWithRetry(config);
    cache = await _connectRedisWithRetry(config);
  }

  await store.initialize();
  if (config.seedDemoData) {
    await seedDemoTenants(
      store,
      defaultWebhookUrl: config.defaultDemoWebhookUrl,
    );
    print(
      '[BankOS] Demo tenants verified: "banco-andes" and "cooperativa-sol"',
    );
  }

  final webhookService = WebhookService(
    signingSecret: config.webhookSigningSecret,
  );

  final app = BankOsApp(
    config: config,
    store: store,
    cache: cache,
    webhookService: webhookService,
  );

  final server = await shelf_io.serve(
    app.handler,
    config.host,
    config.port,
  );
  server.autoCompress = true;

  print(
    jsonEncode({
      'event': 'server.started',
      'host': server.address.host,
      'port': server.port,
      'api_base': 'http://${server.address.host}:${server.port}/api/v1',
    }),
  );

  Future<void> shutdown(ProcessSignal signal) async {
    print('[BankOS] Received $signal, shutting down gracefully...');
    await server.close(force: false);
    webhookService.close();
    await cache.close();
    await store.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(shutdown);
  }
}

Future<BankStore> _connectPostgresWithRetry(EnvConfig config) async {
  for (var attempt = 1; attempt <= 15; attempt++) {
    try {
      final pg = PostgresBankStore(
        host: config.dbHost,
        port: config.dbPort,
        database: config.dbName,
        username: config.dbUser,
        password: config.dbPassword,
      );
      if (await pg.ping()) {
        print('[BankOS] Connected to PostgreSQL at ${config.dbHost}:${config.dbPort}');
        return pg;
      }
      await pg.close();
    } catch (e) {
      print('[BankOS] Waiting for PostgreSQL (attempt $attempt/15): $e');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError('Unable to connect to PostgreSQL after 15 attempts');
}

Future<CacheStore> _connectRedisWithRetry(EnvConfig config) async {
  for (var attempt = 1; attempt <= 15; attempt++) {
    try {
      final redis = await RedisCacheStore.connect(
        host: config.redisHost,
        port: config.redisPort,
      );
      if (await redis.ping()) {
        print('[BankOS] Connected to Redis at ${config.redisHost}:${config.redisPort}');
        return redis;
      }
      await redis.close();
    } catch (e) {
      print('[BankOS] Waiting for Redis (attempt $attempt/15): $e');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError('Unable to connect to Redis after 15 attempts');
}
