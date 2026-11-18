import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiError implements Exception {
  const ApiError({
    required this.statusCode,
    required this.code,
    required this.message,
    this.correlationId,
  });

  final int statusCode;
  final String code;
  final String message;
  final String? correlationId;

  @override
  String toString() => '[$code] $message';
}

/// Thrown when connectivity drops during a financial operation, carrying the
/// exact [idempotencyKey] and [correlationId] so the UI can retry safely.
class NetworkInterruptedException implements Exception {
  const NetworkInterruptedException({
    required this.message,
    required this.idempotencyKey,
    required this.correlationId,
    required this.attemptsMade,
    this.serverAlreadyReached = false,
  });

  final String message;
  final String idempotencyKey;
  final String correlationId;
  final int attemptsMade;
  final bool serverAlreadyReached;

  @override
  String toString() => message;
}

class RawApiResponse {
  const RawApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.correlationId,
    required this.attemptsUsed,
  });

  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, String> headers;
  final String correlationId;
  final int attemptsUsed;

  bool get wasIdempotencyReplayed =>
      headers['x-idempotency-replayed']?.toLowerCase() == 'true';
}

class BankOsApiClient {
  BankOsApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 12),
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  static const Uuid _uuid = Uuid();

  String _baseUrl;
  final http.Client _httpClient;
  final Duration _timeout;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = _normalizeBaseUrl(newBaseUrl);
  }

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<RawApiResponse> get(
    String path, {
    String? token,
    String? correlationId,
    Map<String, String>? queryParameters,
  }) async {
    final cid = correlationId ?? _uuid.v4();
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters,
    );
    try {
      final response = await _httpClient
          .get(
            uri,
            headers: _buildHeaders(token: token, correlationId: cid),
          )
          .timeout(_timeout);
      return _parseOrThrow(response, cid, attemptsUsed: 1);
    } on SocketException {
      throw ApiError(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Sin conexión con el servidor BankOS ($_baseUrl)',
        correlationId: cid,
      );
    } on TimeoutException {
      throw ApiError(
        statusCode: 0,
        code: 'TIMEOUT',
        message: 'Tiempo de espera agotado al contactar el servidor',
        correlationId: cid,
      );
    } on http.ClientException catch (e) {
      throw ApiError(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Error de red: ${e.message}',
        correlationId: cid,
      );
    }
  }

  Future<RawApiResponse> post(
    String path, {
    required Map<String, Object?> body,
    String? token,
    String? correlationId,
  }) async {
    final cid = correlationId ?? _uuid.v4();
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(token: token, correlationId: cid),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _parseOrThrow(response, cid, attemptsUsed: 1);
    } on SocketException {
      throw ApiError(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Sin conexión con el servidor BankOS ($_baseUrl)',
        correlationId: cid,
      );
    } on TimeoutException {
      throw ApiError(
        statusCode: 0,
        code: 'TIMEOUT',
        message: 'Tiempo de espera agotado',
        correlationId: cid,
      );
    } on http.ClientException catch (e) {
      throw ApiError(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Error de red: ${e.message}',
        correlationId: cid,
      );
    }
  }

  Future<RawApiResponse> patch(
    String path, {
    required Map<String, Object?> body,
    String? token,
    String? correlationId,
  }) async {
    final cid = correlationId ?? _uuid.v4();
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient
        .patch(
          uri,
          headers: _buildHeaders(token: token, correlationId: cid),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _parseOrThrow(response, cid, attemptsUsed: 1);
  }

  Future<RawApiResponse> delete(
    String path, {
    String? token,
    String? correlationId,
    Map<String, String>? queryParameters,
  }) async {
    final cid = correlationId ?? _uuid.v4();
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters,
    );
    final response = await _httpClient
        .delete(
          uri,
          headers: _buildHeaders(token: token, correlationId: cid),
        )
        .timeout(_timeout);
    return _parseOrThrow(response, cid, attemptsUsed: 1);
  }

  /// Sends a mutable financial POST request with mandatory [idempotencyKey] and
  /// [correlationId]. Automatically retries transient connectivity failures
  /// using the EXACT SAME keys.
  ///
  /// When [simulateResponseDrop] is true (for live hackathon idempotency demo),
  /// the request hits the server and executes once, then simulates a mobile
  /// connectivity drop before reading the confirmation so the user can tap
  /// "Reintentar" with the exact same Idempotency-Key and verify zero double charge.
  Future<RawApiResponse> postIdempotent(
    String path, {
    required Map<String, Object?> body,
    required String token,
    required String idempotencyKey,
    required String correlationId,
    int maxAutoRetries = 1,
    bool simulateResponseDrop = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = _buildHeaders(
      token: token,
      correlationId: correlationId,
      idempotencyKey: idempotencyKey,
    );

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _httpClient
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_timeout);

        if (simulateResponseDrop) {
          throw NetworkInterruptedException(
            message:
                'Conectividad perdida tras enviar la operación. El servidor pudo haberla procesado; reintente usando exactamente la misma Idempotency-Key para evitar doble cobro.',
            idempotencyKey: idempotencyKey,
            correlationId: correlationId,
            attemptsMade: attempt,
            serverAlreadyReached: true,
          );
        }

        return _parseOrThrow(response, correlationId, attemptsUsed: attempt);
      } on NetworkInterruptedException {
        rethrow;
      } on SocketException {
        if (attempt <= maxAutoRetries) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        throw NetworkInterruptedException(
          message:
              'Pérdida de conexión durante el envío. Puede reintentar de forma segura con la misma Idempotency-Key.',
          idempotencyKey: idempotencyKey,
          correlationId: correlationId,
          attemptsMade: attempt,
        );
      } on TimeoutException {
        if (attempt <= maxAutoRetries) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        throw NetworkInterruptedException(
          message:
              'Tiempo de espera agotado. Reintente con la misma Idempotency-Key para confirmar el resultado sin doble cobro.',
          idempotencyKey: idempotencyKey,
          correlationId: correlationId,
          attemptsMade: attempt,
        );
      } on http.ClientException {
        if (attempt <= maxAutoRetries) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        throw NetworkInterruptedException(
          message:
              'Interrupción de red detectada. Reintente usando exactamente la misma Idempotency-Key.',
          idempotencyKey: idempotencyKey,
          correlationId: correlationId,
          attemptsMade: attempt,
        );
      }
    }
  }

  Map<String, String> _buildHeaders({
    String? token,
    required String correlationId,
    String? idempotencyKey,
  }) {
    return {
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      'x-correlation-id': correlationId,
      if (token != null) 'authorization': 'Bearer $token',
      if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
    };
  }

  RawApiResponse _parseOrThrow(
    http.Response response,
    String fallbackCorrelationId, {
    required int attemptsUsed,
  }) {
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      decoded = raw is Map<String, dynamic>
          ? raw
          : {'success': false, 'message': response.body};
    } catch (_) {
      decoded = {'success': false, 'message': response.body};
    }

    final cid = response.headers['x-correlation-id'] ?? fallbackCorrelationId;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return RawApiResponse(
        statusCode: response.statusCode,
        body: decoded,
        headers: response.headers,
        correlationId: cid,
        attemptsUsed: attemptsUsed,
      );
    }

    throw ApiError(
      statusCode: response.statusCode,
      code: decoded['code'] as String? ?? 'HTTP_${response.statusCode}',
      message: decoded['message'] as String? ?? 'Error en la operación',
      correlationId: cid,
    );
  }
}
