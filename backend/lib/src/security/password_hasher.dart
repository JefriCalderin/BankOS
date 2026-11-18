import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Salted iterative HMAC-SHA256 password hasher (pure Dart, constant-time verify).
class PasswordHasher {
  static const int _iterations = 15000;
  static const int _saltBytes = 16;

  static String hash(String password) {
    final rng = Random.secure();
    final salt = List<int>.generate(_saltBytes, (_) => rng.nextInt(256));
    final saltB64 = base64UrlEncode(salt);
    final derived = _derive(password, salt, _iterations);
    return 'v1\$$_iterations\$$saltB64\$${base64UrlEncode(derived)}';
  }

  static bool verify(String password, String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length != 4 || parts[0] != 'v1') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;
    final salt = base64Url.decode(parts[2]);
    final expected = base64Url.decode(parts[3]);
    final actual = _derive(password, salt, iterations);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static List<int> _derive(String password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var current = hmac.convert(salt).bytes;
    for (var i = 1; i < iterations; i++) {
      current = hmac.convert(current).bytes;
    }
    return current;
  }
}
