import 'package:redis/redis.dart';

class RateLimitCounter {
  const RateLimitCounter({
    required this.count,
    required this.ttlSeconds,
  });

  final int count;
  final int ttlSeconds;
}

abstract class CacheStore {
  Future<bool> setIfNotExists(String key, String value, int ttlSeconds);
  Future<void> set(String key, String value, int ttlSeconds);
  Future<String?> get(String key);
  Future<void> delete(String key);
  Future<RateLimitCounter> incrementWithExpiry(String key, int windowSeconds);
  Future<bool> ping();
  Future<void> close();
}

class RedisCacheStore implements CacheStore {
  RedisCacheStore._(this._connection, this._command);

  final RedisConnection _connection;
  final Command _command;

  static Future<RedisCacheStore> connect({
    required String host,
    required int port,
  }) async {
    final connection = RedisConnection();
    final command = await connection.connect(host, port);
    return RedisCacheStore._(connection, command);
  }

  @override
  Future<bool> setIfNotExists(String key, String value, int ttlSeconds) async {
    final result =
        await _command.send_object(['SET', key, value, 'NX', 'EX', ttlSeconds]);
    return result == 'OK';
  }

  @override
  Future<void> set(String key, String value, int ttlSeconds) async {
    await _command.send_object(['SET', key, value, 'EX', ttlSeconds]);
  }

  @override
  Future<String?> get(String key) async {
    final result = await _command.send_object(['GET', key]);
    if (result == null) return null;
    return result.toString();
  }

  @override
  Future<void> delete(String key) async {
    await _command.send_object(['DEL', key]);
  }

  @override
  Future<RateLimitCounter> incrementWithExpiry(
    String key,
    int windowSeconds,
  ) async {
    final countRaw = await _command.send_object(['INCR', key]);
    final count = (countRaw as num).toInt();
    if (count == 1) {
      await _command.send_object(['EXPIRE', key, windowSeconds]);
      return RateLimitCounter(count: count, ttlSeconds: windowSeconds);
    }
    final ttlRaw = await _command.send_object(['TTL', key]);
    final ttl = (ttlRaw is num && ttlRaw > 0) ? ttlRaw.toInt() : windowSeconds;
    return RateLimitCounter(count: count, ttlSeconds: ttl);
  }

  @override
  Future<bool> ping() async {
    try {
      final result = await _command.send_object(['PING']);
      return result == 'PONG';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _connection.close();
  }
}

class _MemoryEntry {
  _MemoryEntry(this.value, this.expiresAt);
  String value;
  DateTime expiresAt;
}

class InMemoryCacheStore implements CacheStore {
  InMemoryCacheStore({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _MemoryEntry> _store = {};

  void _evictIfExpired(String key) {
    final entry = _store[key];
    if (entry != null && !_clock().isBefore(entry.expiresAt)) {
      _store.remove(key);
    }
  }

  @override
  Future<bool> setIfNotExists(String key, String value, int ttlSeconds) async {
    _evictIfExpired(key);
    if (_store.containsKey(key)) return false;
    _store[key] = _MemoryEntry(
      value,
      _clock().add(Duration(seconds: ttlSeconds)),
    );
    return true;
  }

  @override
  Future<void> set(String key, String value, int ttlSeconds) async {
    _store[key] = _MemoryEntry(
      value,
      _clock().add(Duration(seconds: ttlSeconds)),
    );
  }

  @override
  Future<String?> get(String key) async {
    _evictIfExpired(key);
    return _store[key]?.value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<RateLimitCounter> incrementWithExpiry(
    String key,
    int windowSeconds,
  ) async {
    _evictIfExpired(key);
    final existing = _store[key];
    if (existing == null) {
      final expiresAt = _clock().add(Duration(seconds: windowSeconds));
      _store[key] = _MemoryEntry('1', expiresAt);
      return RateLimitCounter(count: 1, ttlSeconds: windowSeconds);
    }
    final next = (int.tryParse(existing.value) ?? 0) + 1;
    existing.value = next.toString();
    final remaining = existing.expiresAt.difference(_clock()).inSeconds;
    return RateLimitCounter(
      count: next,
      ttlSeconds: remaining > 0 ? remaining : 1,
    );
  }

  @override
  Future<bool> ping() async => true;

  @override
  Future<void> close() async {}
}
