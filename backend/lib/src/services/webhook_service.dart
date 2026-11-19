import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class WebhookEventRecord {
  const WebhookEventRecord({
    required this.url,
    required this.eventType,
    required this.tenantId,
    required this.correlationId,
    required this.payload,
  });

  final String url;
  final String eventType;
  final String tenantId;
  final String correlationId;
  final Map<String, Object?> payload;
}

class WebhookService {
  WebhookService({
    required this.signingSecret,
    http.Client? httpClient,
    this.onDispatched,
  }) : _httpClient = httpClient ?? http.Client();

  final String signingSecret;
  final http.Client _httpClient;
  final void Function(WebhookEventRecord record)? onDispatched;
  final List<WebhookEventRecord> _recentEvents = [];

  List<Map<String, Object?>> getRecentEvents(String tenantId) {
    return _recentEvents
        .where((e) => e.tenantId == tenantId)
        .map((e) => {
              'url': e.url,
              'event': e.eventType,
              'tenant_id': e.tenantId,
              'correlation_id': e.correlationId,
              'payload': e.payload,
            })
        .toList();
  }

  /// Dispatches an asynchronous non-blocking HTTP POST webhook notification.
  void dispatchAsync({
    required String? webhookUrl,
    required String tenantId,
    required String tenantSlug,
    required String eventType,
    required String correlationId,
    required Map<String, Object?> data,
  }) {
    if (webhookUrl == null || webhookUrl.trim().isEmpty) return;

    final payload = <String, Object?>{
      'event': eventType,
      'tenant_id': tenantId,
      'tenant_slug': tenantSlug,
      'correlation_id': correlationId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };

    final record = WebhookEventRecord(
      url: webhookUrl,
      eventType: eventType,
      tenantId: tenantId,
      correlationId: correlationId,
      payload: payload,
    );

    _recentEvents.insert(0, record);
    if (_recentEvents.length > 60) {
      _recentEvents.removeLast();
    }

    onDispatched?.call(record);

    unawaited(_send(webhookUrl, eventType, correlationId, payload));
  }

  Future<void> _send(
    String url,
    String eventType,
    String correlationId,
    Map<String, Object?> payload,
  ) async {
    try {
      final body = jsonEncode(payload);
      final signature = Hmac(sha256, utf8.encode(signingSecret))
          .convert(utf8.encode(body))
          .toString();

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-correlation-id': correlationId,
              'x-bankos-event': eventType,
              'x-bankos-signature': 'sha256=$signature',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      print(
        jsonEncode({
          'level': 'INFO',
          'event': 'webhook.delivered',
          'correlation_id': correlationId,
          'webhook_event': eventType,
          'url': url,
          'status_code': response.statusCode,
        }),
      );
    } catch (e) {
      print(
        jsonEncode({
          'level': 'WARN',
          'event': 'webhook.delivery_failed',
          'correlation_id': correlationId,
          'webhook_event': eventType,
          'url': url,
          'error': e.toString(),
        }),
      );
    }
  }

  void close() => _httpClient.close();
}
