import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../cache/cache_store.dart';
import '../db/bank_store.dart';
import '../models/api_response.dart';

/// Enforces mandatory Idempotency-Key handling scoped strictly to
/// (tenant_id, user_id) with 24-hour expiration, concurrent lock protection
/// (409 Conflict), and exact response replay.
class IdempotencyService {
  IdempotencyService({
    required CacheStore cache,
    required BankStore store,
  })  : _cache = cache,
        _store = store;

  static const int ttlSeconds = 24 * 60 * 60; // 24 hours
  static const String _inProgressState = 'IN_PROGRESS';
  static const String _completedState = 'COMPLETED';

  final CacheStore _cache;
  final BankStore _store;

  String validateKey(String? rawKey) {
    final key = rawKey?.trim() ?? '';
    if (key.isEmpty) {
      throw const AppException(
        statusCode: 400,
        code: 'IDEMPOTENCY_KEY_REQUIRED',
        message: 'El encabezado Idempotency-Key (UUID) es obligatorio para operaciones financieras',
      );
    }
    if (!Uuid.isValidUUID(fromString: key)) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_IDEMPOTENCY_KEY',
        message: 'El encabezado Idempotency-Key debe ser un UUID válido',
      );
    }
    return key;
  }

  String _cacheKey(String tenantId, String userId, String key) =>
      'idem:$tenantId:$userId:$key';

  Future<Response> execute({
    required String tenantId,
    required String userId,
    required String? rawKey,
    required String correlationId,
    required Future<Response> Function(String validatedKey) operation,
  }) async {
    final key = validateKey(rawKey);
    final cacheKey = _cacheKey(tenantId, userId, key);

    // 1. Atomic acquire lock in Redis/Cache (NX + 24h TTL)
    final lockPayload = jsonEncode({
      'state': _inProgressState,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
    final acquired =
        await _cache.setIfNotExists(cacheKey, lockPayload, ttlSeconds);

    if (!acquired) {
      // Key already exists in cache: either IN_PROGRESS (concurrent) or COMPLETED (replay).
      final existingRaw = await _cache.get(cacheKey);
      if (existingRaw != null) {
        final decoded = jsonDecode(existingRaw) as Map<String, dynamic>;
        final state = decoded['state'] as String?;
        if (state == _completedState) {
          return _buildReplayResponse(
            statusCode: (decoded['status_code'] as num).toInt(),
            body: decoded['body'] as String,
            correlationId: correlationId,
          );
        }
        // Still IN_PROGRESS concurrently!
        throw const AppException(
          statusCode: 409,
          code: 'TRANSACTION_IN_PROGRESS',
          message:
              'Ya existe una transacción en curso con esta Idempotency-Key. Espere y reintente.',
        );
      }
    }

    // 2. Also check durable PostgreSQL backup in case cache was evicted/restarted
    final persisted = await _store.getIdempotencyRecord(
      tenantId: tenantId,
      userId: userId,
      key: key,
    );
    if (persisted != null) {
      final completedPayload = jsonEncode({
        'state': _completedState,
        'status_code': persisted.statusCode,
        'body': persisted.responseBody,
      });
      await _cache.set(cacheKey, completedPayload, ttlSeconds);
      return _buildReplayResponse(
        statusCode: persisted.statusCode,
        body: persisted.responseBody,
        correlationId: correlationId,
      );
    }

    // 3. Execute the actual financial operation
    try {
      final response = await operation(key);
      final responseBody = await response.readAsString();

      // Persist successful responses (2xx) for exact replay over the next 24h
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final completedPayload = jsonEncode({
          'state': _completedState,
          'status_code': response.statusCode,
          'body': responseBody,
        });
        await _cache.set(cacheKey, completedPayload, ttlSeconds);
        await _store.saveIdempotencyRecord(
          tenantId: tenantId,
          userId: userId,
          key: key,
          statusCode: response.statusCode,
          responseBody: responseBody,
          expiresAt: DateTime.now().toUtc().add(const Duration(seconds: ttlSeconds)),
        );
      } else {
        // Business/client error (4xx) did not complete financially -> release lock
        await _cache.delete(cacheKey);
      }

      return Response(
        response.statusCode,
        body: responseBody,
        headers: {
          ...response.headers,
          'x-idempotency-key': key,
          'x-idempotency-replayed': 'false',
        },
      );
    } catch (_) {
      // Release lock on exception so a legitimate retry can proceed
      await _cache.delete(cacheKey);
      rethrow;
    }
  }

  Response _buildReplayResponse({
    required int statusCode,
    required String body,
    required String correlationId,
  }) {
    return Response(
      statusCode,
      body: body,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'x-correlation-id': correlationId,
        'x-idempotency-replayed': 'true',
      },
    );
  }
}
