import 'package:flutter/material.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/security_auth_dialog.dart';
import '../../../core/theme.dart';
import '../view_models/operations_view_model.dart';

class PreTransactionSummaryView extends StatefulWidget {
  const PreTransactionSummaryView({
    super.key,
    required this.viewModel,
    required this.authRepository,
    required this.onOperationCompleted,
  });

  final OperationsViewModel viewModel;
  final AuthRepository authRepository;
  final VoidCallback onOperationCompleted;

  @override
  State<PreTransactionSummaryView> createState() =>
      _PreTransactionSummaryViewState();
}

class _PreTransactionSummaryViewState extends State<PreTransactionSummaryView> {
  bool _simulateNetworkDrop = false;

  String _titleFor(OperationKind kind) {
    return switch (kind) {
      OperationKind.deposit => 'Resumen de Depósito',
      OperationKind.withdrawal => 'Resumen de Retiro',
      OperationKind.transfer => 'Resumen de Transferencia',
    };
  }

  Future<void> _confirmAndSend(OperationDraft draft) async {
    if (draft.requiresLocal2FA) {
      final authorized = await SecurityAuthDialog.verify(
        context: context,
        authRepository: widget.authRepository,
        operationLabel: _titleFor(draft.kind),
        amountLabel: BankFormatters.money(
          draft.totalDebitAmount,
          draft.sourceCurrency,
        ),
      );
      if (!authorized || !mounted) return;
    }

    final ok = await widget.viewModel.executePendingDraft(
      simulateResponseDrop: _simulateNetworkDrop,
    );
    if (ok) {
      widget.onOperationCompleted();
    }
  }

  Future<void> _retryWithSameKeys() async {
    // Re-executes using the EXACT same Idempotency-Key & X-Correlation-ID
    // without dropping response this time so user gets the exact original receipt.
    final ok = await widget.viewModel.executePendingDraft(
      simulateResponseDrop: false,
      isManualRetry: true,
    );
    if (ok) {
      widget.onOperationCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final draft = widget.viewModel.pendingDraft;
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resumen Pre-Transacción')),
            body: const Center(child: Text('No hay operación pendiente')),
          );
        }

        final receipt = widget.viewModel.receipt;
        final interrupted = widget.viewModel.interruptedError;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titleFor(draft.kind)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Completed Receipt State
              if (receipt != null) ...[
                _ReceiptSuccessCard(
                  receipt: receipt,
                  draft: draft,
                  onDone: () {
                    widget.viewModel.resetFlow();
                    Navigator.of(context).pop(true);
                  },
                ),
              ] else ...[
                // Pre-Transaction Breakdown Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: BankOsColors.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Desglose Exacto Pre-Transacción',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: BankOsColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _BreakdownRow(
                          label: draft.kind == OperationKind.deposit
                              ? 'Cuenta a abonar'
                              : 'Cuenta origen',
                          value:
                              '${draft.sourceAccountNumber} (${draft.sourceCurrency})',
                        ),
                        if (draft.destinationAccountNumber != null) ...[
                          _BreakdownRow(
                            label: 'Cuenta destino',
                            value:
                                '${draft.destinationAccountNumber} (${draft.destinationCurrency})',
                          ),
                          if (draft.destinationOwnerName != null)
                            _BreakdownRow(
                              label: 'Beneficiario',
                              value: draft.destinationOwnerName!,
                            ),
                        ],
                        _BreakdownRow(
                          label: 'Monedas implicadas',
                          value: draft.hasCurrencyConversion
                              ? '${draft.sourceCurrency} → ${draft.destinationCurrency}'
                              : draft.sourceCurrency,
                          highlightColor: draft.hasCurrencyConversion
                              ? BankOsColors.violet
                              : null,
                        ),
                        const Divider(height: 20),
                        _BreakdownRow(
                          label: 'Monto base',
                          value: BankFormatters.money(
                            draft.originalAmount,
                            draft.sourceCurrency,
                          ),
                        ),
                        _BreakdownRow(
                          label: 'Comisión calculada',
                          value: BankFormatters.money(
                            draft.feeAmount,
                            draft.sourceCurrency,
                          ),
                          highlightColor: draft.feeAmount > 0
                              ? BankOsColors.amber
                              : BankOsColors.emerald,
                        ),
                        if (draft.hasCurrencyConversion)
                          _BreakdownRow(
                            label: 'Tasa de cambio aplicada',
                            value:
                                '1 ${draft.sourceCurrency} = ${BankFormatters.rate(draft.exchangeRate)} ${draft.destinationCurrency}',
                            highlightColor: BankOsColors.violet,
                          ),
                        const Divider(height: 20),
                        if (draft.kind != OperationKind.deposit)
                          _BreakdownRow(
                            label: 'Total a debitar',
                            value: BankFormatters.money(
                              draft.totalDebitAmount,
                              draft.sourceCurrency,
                            ),
                            isBold: true,
                          ),
                        _BreakdownRow(
                          label: draft.kind == OperationKind.withdrawal
                              ? 'Monto a retirar'
                              : 'Monto final que recibirá el destino',
                          value: BankFormatters.money(
                            draft.convertedAmount,
                            draft.destinationCurrency,
                          ),
                          isBold: true,
                          highlightColor: BankOsColors.emerald,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Idempotency & Traceability Keys Card
                Card(
                  color: const Color(0xFFF1F5F9),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 18,
                              color: BankOsColors.slate,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Llaves de Idempotencia y Trazabilidad',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: BankOsColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Idempotency-Key: ${draft.idempotencyKey}',
                          key: const Key('summary_idempotency_key'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: BankOsColors.slate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'X-Correlation-ID: ${draft.correlationId}',
                          key: const Key('summary_correlation_id'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: BankOsColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Demo Network Drop Simulator Switch (for Hackathon Judges!)
                if (interrupted == null)
                  Card(
                    child: SwitchListTile(
                      key: const Key('simulate_network_drop_switch'),
                      value: _simulateNetworkDrop,
                      onChanged: widget.viewModel.isExecuting
                          ? null
                          : (v) => setState(() => _simulateNetworkDrop = v),
                      title: const Text(
                        'Simular pérdida de red (Demo Idempotencia)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Simula un corte de conexión tras el envío para probar el reintento con la misma Idempotency-Key sin doble cobro.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),

                // Network Interruption Recovery Panel
                if (interrupted != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('network_retry_banner'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BankOsColors.amberSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: BankOsColors.amber,
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: BankOsColors.amber,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Conexión Interrumpida — Reintento Seguro',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: BankOsColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          interrupted.message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: BankOsColors.slate,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Se reutilizará exactamente la llave:\n${interrupted.idempotencyKey}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: BankOsColors.navy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          key: const Key('retry_same_key_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: BankOsColors.amber,
                          ),
                          onPressed: widget.viewModel.isExecuting
                              ? null
                              : _retryWithSameKeys,
                          icon: widget.viewModel.isExecuting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: const Text(
                            'Reintentar con la misma Idempotency-Key',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (widget.viewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BankOsColors.crimsonSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.viewModel.errorMessage!,
                      style: const TextStyle(
                        color: BankOsColors.crimson,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],

                if (interrupted == null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('confirm_operation_button'),
                    onPressed: widget.viewModel.isExecuting
                        ? null
                        : () => _confirmAndSend(draft),
                    icon: widget.viewModel.isExecuting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            draft.requiresLocal2FA
                                ? Icons.verified_user_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                    label: Text(
                      draft.requiresLocal2FA
                          ? 'Autorizar (2FA) y Confirmar'
                          : 'Confirmar Depósito',
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 13.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: BankOsColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: highlightColor ?? BankOsColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSuccessCard extends StatelessWidget {
  const _ReceiptSuccessCard({
    required this.receipt,
    required this.draft,
    required this.onDone,
  });

  final ExecutionReceipt receipt;
  final OperationDraft draft;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tx = receipt.transaction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: BankOsColors.emeraldSoft,
              child: Icon(
                Icons.check_circle_rounded,
                color: BankOsColors.emerald,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¡Operación Exitosa!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: BankOsColors.navy,
              ),
            ),
            if (receipt.wasReplayed) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('idempotency_replayed_badge'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BankOsColors.emeraldSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BankOsColors.emerald),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: BankOsColors.emerald,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Idempotencia verificada: respuesta recuperada del servidor SIN doble cobro.',
                        style: TextStyle(
                          color: BankOsColors.emerald,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 26),
            _BreakdownRow(
              label: 'Monto original',
              value: BankFormatters.money(
                tx.originalAmount,
                tx.originalCurrency,
              ),
            ),
            if (tx.feeAmount > 0)
              _BreakdownRow(
                label: 'Comisión cobrada',
                value: BankFormatters.money(tx.feeAmount, tx.feeCurrency),
                highlightColor: BankOsColors.amber,
              ),
            if (tx.hasCurrencyConversion)
              _BreakdownRow(
                label: 'Conversión FX',
                value:
                    '1 ${tx.originalCurrency} = ${BankFormatters.rate(tx.exchangeRate)} ${tx.destinationCurrency}',
                highlightColor: BankOsColors.violet,
              ),
            _BreakdownRow(
              label: 'Monto final acreditado',
              value: BankFormatters.money(
                tx.convertedAmount,
                tx.destinationCurrency,
              ),
              isBold: true,
              highlightColor: BankOsColors.emerald,
            ),
            const Divider(height: 24),
            Text(
              'ID Transacción: ${tx.id}\nIdempotency-Key: ${tx.idempotencyKey}\nX-Correlation-ID: ${receipt.correlationId}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: BankOsColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onDone,
              child: const Text('Volver al Inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
