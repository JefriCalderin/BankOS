import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Lightweight webhook receiver bundled in docker-compose so judges can
/// inspect delivered asynchronous BankOS webhooks at GET /events.
Future<void> main() async {
  final port = int.tryParse(Platform.environment['WEBHOOK_SINK_PORT'] ?? '') ?? 8085;
  final events = <Map<String, Object?>>[];

  final router = Router()
    ..post('/webhook', (Request request) async {
      final rawBody = await request.readAsString();
      Object? parsedBody;
      try {
        parsedBody = jsonDecode(rawBody);
      } catch (_) {
        parsedBody = rawBody;
      }

      final entry = <String, Object?>{
        'received_at': DateTime.now().toUtc().toIso8601String(),
        'event': request.headers['x-bankos-event'],
        'correlation_id': request.headers['x-correlation-id'],
        'signature': request.headers['x-bankos-signature'],
        'payload': parsedBody,
      };
      events.insert(0, entry);
      if (events.length > 100) {
        events.removeLast();
      }
      print('[WebhookSink] Received ${entry['event']} (${entry['correlation_id']})');
      return Response.ok(
        jsonEncode({'received': true, 'total_stored': events.length}),
        headers: {'content-type': 'application/json'},
      );
    })
    ..get('/events', (Request request) {
      return Response.ok(
        jsonEncode({'count': events.length, 'events': events}),
        headers: {'content-type': 'application/json'},
      );
    });

  final server = await shelf_io.serve(router.call, '0.0.0.0', port);
  print('[WebhookSink] Listening on http://${server.address.host}:${server.port}');
}
