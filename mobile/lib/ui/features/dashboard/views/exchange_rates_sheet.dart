import 'package:flutter/material.dart';

import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';

class ExchangeRatesSheet extends StatefulWidget {
  const ExchangeRatesSheet({
    super.key,
    required this.tenant,
    this.onOpenTransfer,
  });

  final TenantInfo tenant;
  final VoidCallback? onOpenTransfer;

  static Future<void> show(
    BuildContext context, {
    required TenantInfo tenant,
    VoidCallback? onOpenTransfer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExchangeRatesSheet(
        tenant: tenant,
        onOpenTransfer: onOpenTransfer,
      ),
    );
  }

  @override
  State<ExchangeRatesSheet> createState() => _ExchangeRatesSheetState();
}

class _ExchangeRatesSheetState extends State<ExchangeRatesSheet> {
  final _amountController = TextEditingController(text: '100');
  String _fromCurrency = 'USD';
  String _toCurrency = 'COP';

  @override
  void initState() {
    super.initState();
    final rates = widget.tenant.config.exchangeRates;
    if (rates.isNotEmpty) {
      final firstPair = rates.keys.first;
      final parts = firstPair.split('_');
      if (parts.length == 2) {
        _fromCurrency = parts[0];
        _toCurrency = parts[1];
      }
    } else {
      _fromCurrency = widget.tenant.config.baseCurrency;
      _toCurrency = widget.tenant.config.baseCurrency;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double _getRate(String from, String to) {
    if (from == to) return 1.0;
    final rates = widget.tenant.config.exchangeRates;
    final direct = '${from}_$to';
    if (rates.containsKey(direct)) return rates[direct]!;

    final inverse = '${to}_$from';
    if (rates.containsKey(inverse) && rates[inverse]! > 0) {
      return 1.0 / rates[inverse]!;
    }

    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    final rates = tenant.config.exchangeRates;
    final feeLabel = tenant.config.transferFeeType == 'percentage'
        ? '${tenant.config.transferFeeValue}%'
        : BankFormatters.money(
            tenant.config.transferFeeValue,
            tenant.config.baseCurrency,
          );

    final inputAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final currentRate = _getRate(_fromCurrency, _toCurrency);
    final convertedAmount = inputAmount * currentRate;

    // Estimate fee
    final estimatedFee = tenant.config.transferFeeType == 'percentage'
        ? (inputAmount * (tenant.config.transferFeeValue / 100.0))
        : tenant.config.transferFeeValue;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: BankOsColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: BankOsColors.violetSoft,
                      child: Icon(
                        Icons.currency_exchange_rounded,
                        color: BankOsColors.violet,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tasas FX y Conversor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: BankOsColors.navy,
                            ),
                          ),
                          Text(
                            tenant.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: BankOsColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Official Rates List
                    const Text(
                      'Tasas de Cambio Oficiales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BankOsColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (rates.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BankOsColors.slateSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BankOsColors.border),
                        ),
                        child: Text(
                          'Esta entidad opera con divisa única base: ${tenant.config.baseCurrency}. No hay pares FX cruzados activos.',
                          style: const TextStyle(
                            color: BankOsColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...rates.entries.map((entry) {
                        final pair = entry.key.replaceAll('_', ' → ');
                        final rateVal = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: BankOsColors.slateSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: BankOsColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: BankOsColors.violet.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pair,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: BankOsColors.violet,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '1 = ${BankFormatters.rate(rateVal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: BankOsColors.navy,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 18),

                    // Tenant Policy Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BankOsColors.emeraldSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BankOsColors.emerald.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: BankOsColors.emerald,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Políticas Tarifarias del Tenant',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: BankOsColors.emerald,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Divisa Base Institucional: ${tenant.config.baseCurrency}\n'
                            '• Comisión por Transferencia: $feeLabel\n'
                            '• Límite Máximo por Operación: ${BankFormatters.money(tenant.config.maxTransactionLimit, tenant.config.baseCurrency)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: BankOsColors.navy,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Interactive Converter
                    const Text(
                      'Calculadora de Conversión en Vivo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BankOsColors.navy,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Monto a calcular',
                                prefixIcon: const Icon(Icons.calculate_outlined),
                                suffixText: _fromCurrency,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _fromCurrency,
                                    decoration: const InputDecoration(
                                      labelText: 'De',
                                      isDense: true,
                                    ),
                                    items: ['USD', 'COP', 'EUR']
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _fromCurrency = v);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.swap_horiz_rounded),
                                  onPressed: () {
                                    setState(() {
                                      final temp = _fromCurrency;
                                      _fromCurrency = _toCurrency;
                                      _toCurrency = temp;
                                    });
                                  },
                                  tooltip: 'Intercambiar divisas',
                                ),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _toCurrency,
                                    decoration: const InputDecoration(
                                      labelText: 'A',
                                      isDense: true,
                                    ),
                                    items: ['COP', 'USD', 'EUR']
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _toCurrency = v);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 28),

                            // Conversion Result Display
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: BankOsColors.slateSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Monto Convertido:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: BankOsColors.muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          BankFormatters.money(convertedAmount, _toCurrency),
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: BankOsColors.emerald,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Comisión Estimada:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: BankOsColors.muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '${BankFormatters.money(estimatedFee, _fromCurrency)} ($feeLabel)',
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: BankOsColors.amber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Tasa Aplicada:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: BankOsColors.muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '1 $_fromCurrency = ${BankFormatters.rate(currentRate)} $_toCurrency',
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: BankOsColors.violet,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            if (widget.onOpenTransfer != null) ...[
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenTransfer?.call();
                                },
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('Realizar Transferencia'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
