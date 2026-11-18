import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../models/api_response.dart';
import '../models/domain_models.dart';

class JwtService {
  const JwtService({
    required this.secret,
    required this.expiryHours,
  });

  final String secret;
  final int expiryHours;

  String sign({
    required String tenantId,
    required String tenantSlug,
    required String userId,
    required String email,
    required UserRole role,
  }) {
    final jwt = JWT(
      {
        'tenant_id': tenantId,
        'tenant_slug': tenantSlug,
        'user_id': userId,
        'email': email,
        'role': role.value,
      },
      issuer: 'bankos-api-v1',
      subject: userId,
    );

    return jwt.sign(
      SecretKey(secret),
      expiresIn: Duration(hours: expiryHours),
    );
  }

  AuthContext verify(String token) {
    try {
      final verified = JWT.verify(token, SecretKey(secret));
      final payload = verified.payload;
      if (payload is! Map) {
        throw const AppException(
          statusCode: 401,
          code: 'INVALID_TOKEN',
          message: 'Token JWT con payload inválido',
        );
      }

      final tenantId = payload['tenant_id'] as String?;
      final tenantSlug = payload['tenant_slug'] as String?;
      final userId = payload['user_id'] as String?;
      final email = payload['email'] as String?;
      final roleRaw = payload['role'] as String?;

      if (tenantId == null ||
          tenantSlug == null ||
          userId == null ||
          email == null ||
          roleRaw == null) {
        throw const AppException(
          statusCode: 401,
          code: 'INVALID_TOKEN_CLAIMS',
          message: 'El token no contiene los claims requeridos',
        );
      }

      return AuthContext(
        tenantId: tenantId,
        tenantSlug: tenantSlug,
        userId: userId,
        email: email,
        role: UserRole.fromString(roleRaw),
      );
    } on JWTExpiredException {
      throw const AppException(
        statusCode: 401,
        code: 'TOKEN_EXPIRED',
        message: 'La sesión ha expirado. Inicie sesión nuevamente.',
      );
    } on JWTException {
      throw const AppException(
        statusCode: 401,
        code: 'INVALID_TOKEN',
        message: 'Token de autenticación inválido',
      );
    } on FormatException {
      throw const AppException(
        statusCode: 401,
        code: 'INVALID_TOKEN_ROLE',
        message: 'Rol de usuario inválido en el token',
      );
    }
  }
}
