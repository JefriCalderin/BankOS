import 'dart:io';

class EnvConfig {
  const EnvConfig({
    required this.host,
    required this.port,
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
    required this.redisHost,
    required this.redisPort,
    required this.jwtSecret,
    required this.jwtExpiryHours,
    required this.webhookSigningSecret,
    required this.defaultDemoWebhookUrl,
    required this.authRateLimitMax,
    required this.authRateLimitWindowSeconds,
    required this.txRateLimitMax,
    required this.txRateLimitWindowSeconds,
    required this.seedDemoData,
    required this.useInMemoryFallback,
  });

  factory EnvConfig.fromEnvironment([Map<String, String>? env]) {
    final map = env ?? Platform.environment;
    return EnvConfig(
      host: map['HOST'] ?? '0.0.0.0',
      port: int.tryParse(map['PORT'] ?? '') ?? 8080,
      dbHost: map['DB_HOST'] ?? 'localhost',
      dbPort: int.tryParse(map['DB_PORT'] ?? '') ?? 5432,
      dbName: map['DB_NAME'] ?? 'bankos',
      dbUser: map['DB_USER'] ?? 'bankos',
      dbPassword: map['DB_PASSWORD'] ?? 'bankos_secret',
      redisHost: map['REDIS_HOST'] ?? 'localhost',
      redisPort: int.tryParse(map['REDIS_PORT'] ?? '') ?? 6379,
      jwtSecret: map['JWT_SECRET'] ??
          'bankos-dev-secret-key-please-override-in-production',
      jwtExpiryHours: int.tryParse(map['JWT_EXPIRY_HOURS'] ?? '') ?? 24,
      webhookSigningSecret:
          map['WEBHOOK_SIGNING_SECRET'] ?? 'bankos-webhook-hmac-secret',
      defaultDemoWebhookUrl:
          map['DEFAULT_DEMO_WEBHOOK_URL'] ?? 'http://localhost:8085/webhook',
      authRateLimitMax: int.tryParse(map['AUTH_RATE_LIMIT_MAX'] ?? '') ?? 20,
      authRateLimitWindowSeconds:
          int.tryParse(map['AUTH_RATE_LIMIT_WINDOW_SECONDS'] ?? '') ?? 60,
      txRateLimitMax: int.tryParse(map['TX_RATE_LIMIT_MAX'] ?? '') ?? 60,
      txRateLimitWindowSeconds:
          int.tryParse(map['TX_RATE_LIMIT_WINDOW_SECONDS'] ?? '') ?? 60,
      seedDemoData: (map['SEED_DEMO_DATA'] ?? 'true').toLowerCase() == 'true',
      useInMemoryFallback:
          (map['USE_IN_MEMORY'] ?? 'false').toLowerCase() == 'true',
    );
  }

  final String host;
  final int port;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final String redisHost;
  final int redisPort;
  final String jwtSecret;
  final int jwtExpiryHours;
  final String webhookSigningSecret;
  final String defaultDemoWebhookUrl;
  final int authRateLimitMax;
  final int authRateLimitWindowSeconds;
  final int txRateLimitMax;
  final int txRateLimitWindowSeconds;
  final bool seedDemoData;
  final bool useInMemoryFallback;
}
