import '../cache/cache_store.dart';
import '../models/api_response.dart';

class RateLimitOutcome {
  const RateLimitOutcome({
    required this.limit,
    required this.remaining,
    required this.resetSeconds,
  });

  final int limit;
  final int remaining;
  final int resetSeconds;

  Map<String, String> toHeaders() => {
        'x-ratelimit-limit': '$limit',
        'x-ratelimit-remaining': '$remaining',
        'x-ratelimit-reset': '$resetSeconds',
      };
}

class RateLimiterService {
  const RateLimiterService({required CacheStore cache}) : _cache = cache;

  final CacheStore _cache;

  /// Enforces dual rate limiting: by client IP AND (when available) by user account.
  Future<RateLimitOutcome> check({
    required String scope,
    required String clientIp,
    String? accountKey,
    required int maxRequests,
    required int windowSeconds,
  }) async {
    final ipResult = await _cache.incrementWithExpiry(
      'rl:$scope:ip:$clientIp',
      windowSeconds,
    );
    if (ipResult.count > maxRequests) {
      throw AppException(
        statusCode: 429,
        code: 'RATE_LIMIT_EXCEEDED',
        message:
            'Demasiadas peticiones desde esta dirección IP. Intente nuevamente en ${ipResult.ttlSeconds}s.',
        extraHeaders: {
          'retry-after': '${ipResult.ttlSeconds}',
          'x-ratelimit-limit': '$maxRequests',
          'x-ratelimit-remaining': '0',
        },
      );
    }

    var worstCount = ipResult.count;
    var worstTtl = ipResult.ttlSeconds;

    if (accountKey != null && accountKey.trim().isNotEmpty) {
      final normalizedAccount = accountKey.trim().toLowerCase();
      final userResult = await _cache.incrementWithExpiry(
        'rl:$scope:user:$normalizedAccount',
        windowSeconds,
      );
      if (userResult.count > maxRequests) {
        throw AppException(
          statusCode: 429,
          code: 'USER_RATE_LIMIT_EXCEEDED',
          message:
              'Límite de peticiones excedido para esta cuenta de usuario. Intente en ${userResult.ttlSeconds}s.',
          extraHeaders: {
            'retry-after': '${userResult.ttlSeconds}',
            'x-ratelimit-limit': '$maxRequests',
            'x-ratelimit-remaining': '0',
          },
        );
      }
      if (userResult.count > worstCount) {
        worstCount = userResult.count;
        worstTtl = userResult.ttlSeconds;
      }
    }

    final remaining = (maxRequests - worstCount).clamp(0, maxRequests);
    return RateLimitOutcome(
      limit: maxRequests,
      remaining: remaining,
      resetSeconds: worstTtl,
    );
  }
}
