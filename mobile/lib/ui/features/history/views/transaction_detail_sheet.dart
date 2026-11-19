import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';

class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({super.key, required this.tx});

  final TransactionItem tx;

  static Future<void> show(BuildContext context, TransactionItem tx) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(tx: tx),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icon, typeLabel, iconColor) = switch (tx.type) {
      'deposit' => (
          Icons.arrow_downward_rounded,
          'Depósito Monetario',
          BankOsColors.emerald,
        ),
      'withdrawal' => (
          Icons.arrow_upward_rounded,
          'Retiro de Fondos',
          BankOsColors.crimson,
        ),
      _ => (
          Icons.swap_horiz_rounded,
          'Transferencia Interna',
          BankOsColors.primary,
        ),
    };

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: BankOsColors.navy,
                      ),
                    ),
                    Text(
                      BankFormatters.dateTime(tx.createdAt),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: BankOsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tx.status == 'SUCCESS'
                      ? BankOsColors.emeraldSoft
                      : BankOsColors.crimsonSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tx.status,
                  style: TextStyle(
                    color: tx.status == 'SUCCESS'
                        ? BankOsColors.emerald
                        : BankOsColors.crimson,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Amounts breakdown
          _DetailRow(
            label: 'Monto Original',
            value: BankFormatters.money(tx.originalAmount, tx.originalCurrency),
            isBold: true,
          ),
          if (tx.feeAmount > 0)
            _DetailRow(
              label: 'Comisión Aplicada',
              value: BankFormatters.money(tx.feeAmount, tx.feeCurrency),
              color: BankOsColors.amber,
            ),
          if (tx.totalDebited > 0)
            _DetailRow(
              label: 'Total Debitado en Origen',
              value: BankFormatters.money(tx.totalDebited, tx.originalCurrency),
              isBold: true,
            ),
          if (tx.hasCurrencyConversion) ...[
            _DetailRow(
              label: 'Tasa de Cambio FX',
              value:
                  '1 ${tx.originalCurrency} = ${BankFormatters.rate(tx.exchangeRate)} ${tx.destinationCurrency}',
              color: BankOsColors.violet,
            ),
            _DetailRow(
              label: 'Monto Acreditado en Destino',
              value:
                  BankFormatters.money(tx.convertedAmount, tx.destinationCurrency),
              isBold: true,
              color: BankOsColors.emerald,
            ),
          ],

          if (tx.sourceAccountNumber != null ||
              tx.destinationAccountNumber != null) ...[
            const Divider(height: 18),
            if (tx.sourceAccountNumber != null)
              _DetailRow(
                label: 'Cuenta Origen',
                value: tx.sourceAccountNumber!,
              ),
            if (tx.destinationAccountNumber != null)
              _DetailRow(
                label: 'Cuenta Destino',
                value: tx.destinationAccountNumber!,
              ),
          ],

          if (tx.description != null && tx.description!.isNotEmpty) ...[
            const Divider(height: 18),
            _DetailRow(label: 'Descripción', value: tx.description!),
          ],

          const Divider(height: 22),

          // Technical traceability keys
          const Text(
            'Trazabilidad e Idempotencia (Auditoría)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: BankOsColors.navy,
            ),
          ),
          const SizedBox(height: 8),

          _KeyCopyTile(
            label: 'Idempotency-Key',
            value: tx.idempotencyKey,
            onCopy: () => _copyToClipboard(
              context,
              tx.idempotencyKey,
              'Idempotency-Key',
            ),
          ),
          const SizedBox(height: 6),
          _KeyCopyTile(
            label: 'X-Correlation-ID',
            value: tx.correlationId,
            onCopy: () => _copyToClipboard(
              context,
              tx.correlationId,
              'X-Correlation-ID',
            ),
          ),
          const SizedBox(height: 6),
          _KeyCopyTile(
            label: 'ID Transacción',
            value: tx.id,
            onCopy: () => _copyToClipboard(
              context,
              tx.id,
              'ID Transacción',
            ),
          ),

          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: BankOsColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? BankOsColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyCopyTile extends StatelessWidget {
  const _KeyCopyTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BankOsColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BankOsColors.muted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: BankOsColors.navy,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: onCopy,
            visualDensity: VisualDensity.compact,
            tooltip: 'Copiar $label',
          ),
        ],
      ),
    );
  }
}
