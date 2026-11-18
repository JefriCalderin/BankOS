import 'package:shelf/shelf.dart';

import 'cache/cache_store.dart';
import 'config/env_config.dart';
import 'db/bank_store.dart';
import 'middleware/middlewares.dart';
import 'routes/api_router.dart';
import 'security/jwt_service.dart';
import 'services/banking_service.dart';
import 'services/currency_service.dart';
import 'services/idempotency_service.dart';
import 'services/rate_limiter_service.dart';
import 'services/webhook_service.dart';

class BankOsApp {
  BankOsApp({
    required this.config,
    required this.store,
    required this.cache,
    required this.webhookService,
    bool enableRequestLogging = true,
  })  : jwtService = JwtService(
          secret: config.jwtSecret,
          expiryHours: config.jwtExpiryHours,
        ),
        currencyService = const CurrencyService() {
    bankingService = BankingService(
      store: store,
      jwtService: jwtService,
      currencyService: currencyService,
      webhookService: webhookService,
    );
    idempotencyService = IdempotencyService(cache: cache, store: store);
    rateLimiterService = RateLimiterService(cache: cache);

    final apiRouter = ApiV1Router(
      config: config,
      store: store,
      cache: cache,
      jwtService: jwtService,
      bankingService: bankingService,
      idempotencyService: idempotencyService,
      rateLimiter: rateLimiterService,
    );

    handler = const Pipeline()
        .addMiddleware(corsMiddleware())
        .addMiddleware(
          correlationAndLoggingMiddleware(enableLogging: enableRequestLogging),
        )
        .addMiddleware(errorHandlerMiddleware())
        .addHandler(apiRouter.router.call);
  }

  final EnvConfig config;
  final BankStore store;
  final CacheStore cache;
  final WebhookService webhookService;
  final JwtService jwtService;
  final CurrencyService currencyService;
  late final BankingService bankingService;
  late final IdempotencyService idempotencyService;
  late final RateLimiterService rateLimiterService;
  late final Handler handler;
}
