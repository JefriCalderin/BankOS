import 'dart:convert';
import 'package:shelf/shelf.dart';

class AppException implements Exception {
  const AppException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
    this.extraHeaders,
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, Object?>? details;
  final Map<String, String>? extraHeaders;

  @override
  String toString() => 'AppException($statusCode, $code): $message';
}

class ApiResponse {
  static Response ok({
    required String code,
    required String message,
    required String correlationId,
    Object? data,
    Map<String, Object?>? pagination,
    int statusCode = 200,
    Map<String, String>? extraHeaders,
  }) {
    final body = <String, Object?>{
      'success': true,
      'code': code,
      'message': message,
      if (data != null) 'data': data,
      'meta': <String, Object?>{
        'correlation_id': correlationId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        if (pagination != null) 'pagination': pagination,
      },
    };
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'x-correlation-id': correlationId,
        ...?extraHeaders,
      },
    );
  }

  static Response error({
    required int statusCode,
    required String code,
    required String message,
    required String correlationId,
    Map<String, Object?>? details,
    Map<String, String>? extraHeaders,
  }) {
    final body = <String, Object?>{
      'success': false,
      'code': code,
      'message': message,
      if (details != null) 'details': details,
      'meta': <String, Object?>{
        'correlation_id': correlationId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    };
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'x-correlation-id': correlationId,
        ...?extraHeaders,
      },
    );
  }
}
