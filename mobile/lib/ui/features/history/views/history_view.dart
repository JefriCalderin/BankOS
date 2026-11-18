import 'package:flutter/material.dart';

import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../view_models/history_view_model.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.viewModel});

  final HistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final selected = viewModel.selectedType;
        return RefreshIndicator(
          onRefresh: viewModel.loadFirstPage,
          child: Column(
            children: [
              // Filter Chips Header
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Historial de Transacciones',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: BankOsColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (viewModel.pagination != null)
                          Text(
                            '${viewModel.items.length} / ${viewModel.pagination!.total}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: BankOsColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterPill(
                            key: const Key('filter_all'),
                            label: 'Todas',
                            selected: selected == null,
                            onTap: () => viewModel.setTypeFilter(null),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            key: const Key('filter_deposit'),
                            label: 'Depósitos',
                            selected: selected == 'deposit',
                            onTap: () => viewModel.setTypeFilter('deposit'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            key: const Key('filter_withdrawal'),
                            label: 'Retiros',
                            selected: selected == 'withdrawal',
                            onTap: () => viewModel.setTypeFilter('withdrawal'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            key: const Key('filter_transfer'),
                            label: 'Transferencias',
                            selected: selected == 'transfer',
                            onTap: () => viewModel.setTypeFilter('transfer'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // List Body
              Expanded(
                child: viewModel.isLoading && viewModel.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.errorMessage != null && viewModel.items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    viewModel.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: BankOsColors.crimson,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: viewModel.loadFirstPage,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : viewModel.items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: BankOsColors.muted,
                                  ),
                                  SizedBox(height: 12),
                                  Center(
                                    child: Text(
                                      'No hay transacciones para este filtro.',
                                      style: TextStyle(
                                        color: BankOsColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: viewModel.items.length +
                                    (viewModel.hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == viewModel.items.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: OutlinedButton(
                                        onPressed: viewModel.isLoadingMore
                                            ? null
                                            : viewModel.loadNextPage,
                                        child: viewModel.isLoadingMore
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Cargar más'),
                                      ),
                                    );
                                  }
                                  return _TransactionCard(
                                    tx: viewModel.items[index],
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: BankOsColors.navy,
      labelStyle: TextStyle(
        color: selected ? Colors.white : BankOsColors.navy,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.tx});

  final TransactionItem tx;

  @override
  Widget build(BuildContext context) {
    final hasCostAlert = tx.hasFee || tx.hasCurrencyConversion;

    // Distinct contrasting card border/tint for transactions with commission or FX conversion
    final cardBorderColor = tx.hasCurrencyConversion
        ? BankOsColors.violet
        : (tx.hasFee ? BankOsColors.amber : BankOsColors.border);
    final cardTint = tx.hasCurrencyConversion
        ? BankOsColors.violetSoft.withValues(alpha: 0.45)
        : (tx.hasFee
            ? BankOsColors.amberSoft.withValues(alpha: 0.55)
            : Colors.white);

    final (icon, typeLabel, iconColor) = switch (tx.type) {
      'deposit' => (
          Icons.arrow_downward_rounded,
          'Depósito',
          BankOsColors.emerald,
        ),
      'withdrawal' => (
          Icons.arrow_upward_rounded,
          'Retiro',
          BankOsColors.crimson,
        ),
      _ => (
          Icons.swap_horiz_rounded,
          'Transferencia',
          BankOsColors.primary,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorderColor,
          width: hasCostAlert ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: iconColor.withValues(alpha: 0.12),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: BankOsColors.navy,
                        ),
                      ),
                      Text(
                        BankFormatters.dateTime(tx.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: BankOsColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      BankFormatters.money(
                        tx.originalAmount,
                        tx.originalCurrency,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: tx.type == 'deposit'
                            ? BankOsColors.emerald
                            : BankOsColors.navy,
                      ),
                    ),
                    Text(
                      tx.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tx.status == 'SUCCESS'
                            ? BankOsColors.emerald
                            : BankOsColors.crimson,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (tx.sourceAccountNumber != null ||
                tx.destinationAccountNumber != null) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (tx.sourceAccountNumber != null)
                    'Origen: ${tx.sourceAccountNumber}',
                  if (tx.destinationAccountNumber != null)
                    'Destino: ${tx.destinationAccountNumber}',
                ].join('  →  '),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: BankOsColors.slate,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            if (tx.description != null && tx.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tx.description!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: BankOsColors.muted,
                ),
              ),
            ],

            // High-Contrast Visual Cost Alerts (Commission & FX Conversion)
            if (hasCostAlert) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (tx.hasFee)
                    Container(
                      key: Key('fee_alert_${tx.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BankOsColors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Comisión: ${BankFormatters.money(tx.feeAmount, tx.feeCurrency)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (tx.hasCurrencyConversion)
                    Container(
                      key: Key('fx_alert_${tx.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BankOsColors.violet,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.currency_exchange_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'FX 1 ${tx.originalCurrency}=${BankFormatters.rate(tx.exchangeRate)} ${tx.destinationCurrency} · Destino: ${BankFormatters.money(tx.convertedAmount, tx.destinationCurrency)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Idem: ${BankFormatters.shortUuid(tx.idempotencyKey)} · Corr: ${BankFormatters.shortUuid(tx.correlationId)}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: BankOsColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
