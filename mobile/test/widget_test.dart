import 'dart:convert';

import 'package:bankos_mobile/app.dart';
import 'package:bankos_mobile/data/services/bankos_api_client.dart';
import 'package:bankos_mobile/data/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> mockLoginResponse() => {
        'success': true,
        'code': 'LOGIN_SUCCESS',
        'message': 'Autenticación exitosa',
        'data': {
          'access_token': 'mock-jwt-token',
          'token_type': 'Bearer',
          'expires_in': 86400,
          'user': {
            'id': 'user-ana-1',
            'tenant_id': 'tenant-andes-1',
            'email': 'ana@andes.bank',
            'full_name': 'Ana Sofía Gómez',
            'role': 'cliente',
          },
          'tenant': {
            'id': 'tenant-andes-1',
            'slug': 'banco-andes',
            'name': 'Banco de los Andes',
            'config': {
              'max_transaction_limit': 50000000,
              'transfer_fee_type': 'percentage',
              'transfer_fee_value': 1.5,
              'base_currency': 'COP',
              'exchange_rates': {'USD_COP': 4000.0},
              'webhook_url': 'http://webhook-sink:8085/webhook',
            },
          },
        },
        'meta': {
          'correlation_id': 'corr-login',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      };

  Map<String, dynamic> mockAccountsResponse() => {
        'success': true,
        'code': 'ACCOUNTS_LISTED',
        'message': 'OK',
        'data': {
          'accounts': [
            {
              'id': 'acc-1',
              'tenant_id': 'tenant-andes-1',
              'account_number': 'AND-USD-1001',
              'owner_user_id': 'user-ana-1',
              'owner_name': 'Ana Sofía Gómez',
              'balance': 5000.0,
              'currency': 'USD',
              'status': 'activa',
              'created_at': '2026-11-18T10:00:00Z',
            },
          ],
        },
        'meta': {
          'correlation_id': 'corr-acc',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      };

  Map<String, dynamic> mockTransactionsResponse(String? typeFilter) {
    final all = [
      {
        'id': 'tx-fx-1',
        'type': 'transfer',
        'source_account_number': 'AND-USD-1001',
        'destination_account_number': 'AND-COP-2001',
        'original_amount': 100.0,
        'original_currency': 'USD',
        'converted_amount': 400000.0,
        'destination_currency': 'COP',
        'exchange_rate': 4000.0,
        'fee_amount': 1.5,
        'fee_currency': 'USD',
        'total_debited': 101.5,
        'status': 'SUCCESS',
        'idempotency_key': '11111111-2222-4333-8444-555555555555',
        'correlation_id': 'corr-tx-1',
        'description': 'Pago internacional',
        'created_at': '2026-11-18T11:00:00Z',
      },
      {
        'id': 'tx-dep-2',
        'type': 'deposit',
        'destination_account_number': 'AND-USD-1001',
        'original_amount': 500.0,
        'original_currency': 'USD',
        'converted_amount': 500.0,
        'destination_currency': 'USD',
        'exchange_rate': 1.0,
        'fee_amount': 0.0,
        'fee_currency': 'USD',
        'total_debited': 0.0,
        'status': 'SUCCESS',
        'idempotency_key': '22222222-3333-4444-8555-666666666666',
        'correlation_id': 'corr-tx-2',
        'description': 'Depósito nómina',
        'created_at': '2026-11-18T09:00:00Z',
      },
    ];

    final filtered = (typeFilter == null || typeFilter.isEmpty)
        ? all
        : all.where((t) => t['type'] == typeFilter).toList();

    return {
      'success': true,
      'code': 'TRANSACTIONS_LISTED',
      'message': 'OK',
      'data': {'transactions': filtered},
      'meta': {
        'correlation_id': 'corr-hist',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'pagination': {
          'page': 1,
          'limit': 15,
          'total': filtered.length,
          'total_pages': 1,
          'has_next': false,
        },
      },
    };
  }

  testWidgets(
      'Login -> Dashboard -> Transfer Pre-Summary -> 2FA PIN -> Network Drop -> Retry preserves exact Idempotency-Key & X-Correlation-ID',
      (tester) async {
    final capturedIdempotencyKeys = <String>[];
    final capturedCorrelationIds = <String>[];
    var transferAttemptCount = 0;

    final mockHttp = MockClient((request) async {
      final path = request.url.path;

      if (path == '/api/v1/auth/login') {
        return http.Response(jsonEncode(mockLoginResponse()), 200);
      }
      if (path == '/api/v1/accounts') {
        return http.Response(jsonEncode(mockAccountsResponse()), 200);
      }
      if (path.startsWith('/api/v1/accounts/lookup/')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'code': 'ACCOUNT_FOUND',
            'message': 'OK',
            'data': {
              'account_number': 'AND-COP-2001',
              'owner_name': 'Carlos Andrés Ruiz',
              'currency': 'COP',
              'status': 'activa',
            },
          }),
          200,
        );
      }
      if (path == '/api/v1/transactions/quote') {
        return http.Response(
          jsonEncode({
            'success': true,
            'code': 'TRANSFER_QUOTED',
            'message': 'OK',
            'data': {
              'source_account_number': 'AND-USD-1001',
              'destination_account_number': 'AND-COP-2001',
              'destination_owner_name': 'Carlos Andrés Ruiz',
              'original_amount': 100.0,
              'source_currency': 'USD',
              'fee_amount': 1.5,
              'fee_type': 'percentage',
              'fee_rate_value': 1.5,
              'total_debit_amount': 101.5,
              'exchange_rate': 4000.0,
              'converted_amount': 400000.0,
              'destination_currency': 'COP',
              'has_currency_conversion': true,
            },
          }),
          200,
        );
      }
      if (path == '/api/v1/transactions/transfer') {
        transferAttemptCount++;
        capturedIdempotencyKeys.add(request.headers['idempotency-key'] ?? '');
        capturedCorrelationIds.add(request.headers['x-correlation-id'] ?? '');
        return http.Response(
          jsonEncode({
            'success': true,
            'code': 'TRANSFER_COMPLETED',
            'message': 'OK',
            'data': {
              'transaction': {
                'id': 'tx-new-1',
                'type': 'transfer',
                'source_account_number': 'AND-USD-1001',
                'destination_account_number': 'AND-COP-2001',
                'original_amount': 100.0,
                'original_currency': 'USD',
                'converted_amount': 400000.0,
                'destination_currency': 'COP',
                'exchange_rate': 4000.0,
                'fee_amount': 1.5,
                'fee_currency': 'USD',
                'total_debited': 101.5,
                'status': 'SUCCESS',
                'idempotency_key': request.headers['idempotency-key'],
                'correlation_id': request.headers['x-correlation-id'],
                'created_at': '2026-11-18T12:00:00Z',
              },
            },
          }),
          201,
          headers: {
            'x-correlation-id': request.headers['x-correlation-id'] ?? '',
            'x-idempotency-replayed':
                transferAttemptCount > 1 ? 'true' : 'false',
          },
        );
      }
      if (path == '/api/v1/transactions') {
        return http.Response(
          jsonEncode(
            mockTransactionsResponse(request.url.queryParameters['type']),
          ),
          200,
        );
      }
      return http.Response('{"success":false,"message":"Not found"}', 404);
    });

    final apiClient = BankOsApiClient(
      baseUrl: 'http://localhost:8080',
      httpClient: mockHttp,
    );
    final storage = InMemoryKeyValueStorage();

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BankOsMobileApp(apiClient: apiClient, storage: storage),
    );
    await tester.pumpAndSettle();

    // 1. Login screen requires tenant slug + credentials
    expect(find.byKey(const Key('tenant_slug_field')), findsOneWidget);
    final loginBtn = find.byKey(const Key('login_submit_button'));
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    // 2. Dashboard displays account & balance
    expect(find.text('AND-USD-1001'), findsOneWidget);
    expect(find.textContaining('5,000.00 USD'), findsOneWidget);

    // 3. Navigate to History tab and verify visual cost alerts & filters
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fee_alert_tx-fx-1')), findsOneWidget);
    expect(find.byKey(const Key('fx_alert_tx-fx-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter_deposit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fee_alert_tx-fx-1')), findsNothing);
    expect(find.text('Depósito nómina'), findsOneWidget);

    // 4. Navigate to Operations tab, lookup destination, enter amount, open Pre-Tx Summary
    await tester.tap(find.text('Operar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('dest_account_field')),
      'AND-COP-2001',
    );
    await tester.tap(find.byKey(const Key('lookup_dest_button')));
    await tester.pumpAndSettle();
    expect(find.text('Carlos Andrés Ruiz'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amount_field')), '100');
    await tester.tap(find.byKey(const Key('continue_to_summary_button')));
    await tester.pumpAndSettle();

    // 5. Pre-Transaction Summary displays exact breakdown (fee, FX, debit, credit)
    expect(find.text('Desglose Exacto Pre-Transacción'), findsOneWidget);
    expect(find.textContaining('101.50 USD'), findsOneWidget);
    expect(find.textContaining('400,000 COP'), findsOneWidget);

    // 6. Enable network-drop demo toggle -> Confirm -> Enter 2FA PIN 1234
    final dropSwitch = find.byKey(const Key('simulate_network_drop_switch'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(dropSwitch);
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const Key('confirm_operation_button'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 2FA dialog appears!
    expect(find.byKey(const Key('pin_2fa_field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pin_2fa_field')), '1234');
    await tester.tap(find.byKey(const Key('confirm_pin_2fa_button')));
    await tester.pumpAndSettle();

    // 7. Network retry banner appears; tap Retry with same Idempotency-Key!
    expect(find.byKey(const Key('network_retry_banner')), findsOneWidget);
    final retryBtn = find.byKey(const Key('retry_same_key_button'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(retryBtn);
    await tester.pumpAndSettle();

    // 8. Verify BOTH attempts sent the EXACT SAME Idempotency-Key & X-Correlation-ID!
    expect(capturedIdempotencyKeys.length, 2);
    expect(capturedIdempotencyKeys[0], isNotEmpty);
    expect(capturedIdempotencyKeys[0], equals(capturedIdempotencyKeys[1]));
    expect(capturedCorrelationIds[0], equals(capturedCorrelationIds[1]));

    // 9. Celebratory Idempotency Verified badge is displayed!
    expect(find.byKey(const Key('idempotency_replayed_badge')), findsOneWidget);
  });
}
