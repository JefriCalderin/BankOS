import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../data/repositories/banking_repository.dart';
import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';

class WebhooksViewerSheet extends StatefulWidget {
  const WebhooksViewerSheet({
    super.key,
    required this.bankingRepository,
    required this.tenantName,
  });

  final BankingRepository bankingRepository;
  final String tenantName;

  static Future<void> show(
    BuildContext context, {
    required BankingRepository bankingRepository,
    required String tenantName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WebhooksViewerSheet(
        bankingRepository: bankingRepository,
        tenantName: tenantName,
      ),
    );
  }

  @override
  State<WebhooksViewerSheet> createState() => _WebhooksViewerSheetState();
}

class _WebhooksViewerSheetState extends State<WebhooksViewerSheet> {
  List<DispatchedWebhookItem> _events = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await widget.bankingRepository.fetchRecentWebhooks();
      if (!mounted) return;
      setState(() {
        _events = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron consultar los webhooks: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BankOsColors.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.webhook_rounded,
                  color: BankOsColors.violet,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visor de Webhooks en Vivo',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: BankOsColors.navy,
                      ),
                    ),
                    Text(
                      'Eventos HTTP POST asíncronos disparados (${widget.tenantName})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: BankOsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadEvents,
                tooltip: 'Actualizar webhooks',
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          const Divider(height: 24),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BankOsColors.crimson),
                  ),
                ),
              ),
            )
          else if (_events.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 48,
                      color: BankOsColors.muted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Aún no se han disparado eventos para este tenant.\n(Realiza una transferencia o depósito para disparar uno).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BankOsColors.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final ev = _events[index];
                  final prettyPayload = const JsonEncoder.withIndent('  ')
                      .convert(ev.payload);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BankOsColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: BankOsColors.violetSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ev.event,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: BankOsColors.violet,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Spacer(),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: BankOsColors.emerald,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'HMAC',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: BankOsColors.emerald,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Destino: ${ev.url}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BankOsColors.slate,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'X-Correlation-ID: ${BankFormatters.shortUuid(ev.correlationId)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: BankOsColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BankOsColors.navy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            prettyPayload,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
