import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../models/api_response.dart';
import '../models/domain_models.dart';
import '../security/jwt_service.dart';

const String correlationIdContextKey = 'bankos.correlation_id';
const String authContextKey = 'bankos.auth';

const Uuid _uuid = Uuid();

String getCorrelationId(Request request) {
  return (request.context[correlationIdContextKey] as String?) ??
      request.headers['x-correlation-id'] ??
      'unknown';
}

AuthContext getAuthContext(Request request) {
  final ctx = request.context[authContextKey];
  if (ctx is! AuthContext) {
    throw const AppException(
      statusCode: 401,
      code: 'UNAUTHORIZED',
      message: 'Autenticación requerida',
    );
  }
  return ctx;
}

String extractClientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.trim().isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  final connectionInfo = request.context['shelf.io.connection_info'];
  if (connectionInfo is HttpConnectionInfo) {
    return connectionInfo.remoteAddress.address;
  }
  return '127.0.0.1';
}

/// CORS middleware permitting custom BankOS headers (Idempotency-Key, X-Correlation-ID).
Middleware corsMiddleware() {
  const corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers':
        'Origin, Content-Type, Accept, Authorization, Idempotency-Key, X-Correlation-ID',
    'access-control-expose-headers':
        'X-Correlation-ID, X-Idempotency-Key, X-Idempotency-Replayed, X-RateLimit-Limit, X-RateLimit-Remaining, Retry-After',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method.toUpperCase() == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

/// Propagates or generates `X-Correlation-ID` across request context, structured
/// server logs, and outgoing HTTP response headers.
Middleware correlationAndLoggingMiddleware({bool enableLogging = true}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final incoming = request.headers['x-correlation-id']?.trim();
      final correlationId =
          (incoming != null && incoming.isNotEmpty) ? incoming : _uuid.v4();
      final startedAt = DateTime.now().toUtc();

      final enrichedRequest = request.change(
        context: {correlationIdContextKey: correlationId},
      );

      final response = await innerHandler(enrichedRequest);
      final durationMs =
          DateTime.now().toUtc().difference(startedAt).inMilliseconds;

      if (enableLogging) {
        final auth = enrichedRequest.context[authContextKey];
        print(
          jsonEncode({
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'level': response.statusCode >= 500
                ? 'ERROR'
                : (response.statusCode >= 400 ? 'WARN' : 'INFO'),
            'correlation_id': correlationId,
            'method': request.method,
            'path': '/${request.url.path}',
            'status': response.statusCode,
            'duration_ms': durationMs,
            'client_ip': extractClientIp(request),
            if (auth is AuthContext) 'tenant_id': auth.tenantId,
            if (auth is AuthContext) 'user_id': auth.userId,
          }),
        );
      }

      return response.change(
        headers: {'x-correlation-id': correlationId},
      );
    };
  };
}

/// Converts [AppException], [FormatException], and unhandled exceptions into
/// BankOS's standardized JSON error envelope.
Middleware errorHandlerMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final correlationId = getCorrelationId(request);
      try {
        return await innerHandler(request);
      } on AppException catch (e) {
        return ApiResponse.error(
          statusCode: e.statusCode,
          code: e.code,
          message: e.message,
          correlationId: correlationId,
          details: e.details,
          extraHeaders: e.extraHeaders,
        );
      } on FormatException catch (e) {
        return ApiResponse.error(
          statusCode: 400,
          code: 'INVALID_REQUEST_FORMAT',
          message: e.message,
          correlationId: correlationId,
        );
      } catch (e, st) {
        print(
          jsonEncode({
            'level': 'ERROR',
            'event': 'unhandled_exception',
            'correlation_id': correlationId,
            'error': e.toString(),
            'stack_trace': st.toString().split('\n').take(6).join(' | '),
          }),
        );
        return ApiResponse.error(
          statusCode: 500,
          code: 'INTERNAL_SERVER_ERROR',
          message: 'Error interno procesando la solicitud',
          correlationId: correlationId,
        );
      }
    };
  };
}

/// Verifies `Authorization: Bearer <JWT>` and injects [AuthContext] into request.
AuthContext authenticateRequest(Request request, JwtService jwtService) {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    throw const AppException(
      statusCode: 401,
      code: 'MISSING_AUTH_TOKEN',
      message: 'Encabezado Authorization Bearer requerido',
    );
  }
  final token = authHeader.substring('Bearer '.length).trim();
  if (token.isEmpty) {
    throw const AppException(
      statusCode: 401,
      code: 'MISSING_AUTH_TOKEN',
      message: 'Token Bearer vacío',
    );
  }
  return jwtService.verify(token);
}

void requireRole(AuthContext auth, UserRole requiredRole) {
  if (auth.role != requiredRole) {
    throw AppException(
      statusCode: 403,
      code: 'FORBIDDEN_ROLE',
      message:
          'Esta operación requiere el rol "${requiredRole.value}". Rol actual: "${auth.role.value}".',
    );
  }
}

Future<Map<String, Object?>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const AppException(
        statusCode: 400,
        code: 'INVALID_JSON_OBJECT',
        message: 'El cuerpo de la petición debe ser un objeto JSON',
      );
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  } on FormatException {
    throw const AppException(
      statusCode: 400,
      code: 'MALFORMED_JSON',
      message: 'JSON malformado en el cuerpo de la petición',
    );
  }
}

String requireString(Map<String, Object?> body, String key) {
  final val = body[key];
  if (val is! String || val.trim().isEmpty) {
    throw AppException(
      statusCode: 400,
      code: 'VALIDATION_ERROR',
      message: 'El campo "$key" es obligatorio',
    );
  }
  return val.trim();
}

double requireDouble(Map<String, Object?> body, String key) {
  final val = body[key];
  if (val is num) return val.toDouble();
  if (val is String) {
    final parsed = double.tryParse(val);
    if (parsed != null) return parsed;
  }
  throw AppException(
    statusCode: 400,
    code: 'VALIDATION_ERROR',
    message: 'El campo numérico "$key" es obligatorio y válido',
  );
}
