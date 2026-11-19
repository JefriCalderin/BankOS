import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../view_models/history_view_model.dart';
import 'transaction_detail_sheet.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.viewModel});

  final HistoryViewModel viewModel;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: widget.viewModel.dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: BankOsColors.navy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: BankOsColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await widget.viewModel.setDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final selected = widget.viewModel.selectedType;
        final dateRange = widget.viewModel.dateRange;
        final accountFilterLabel = widget.viewModel.accountNumberFilterLabel;

        final displayedItems = _searchQuery.isEmpty
            ? widget.viewModel.items
            : widget.viewModel.items.where((t) {
                final desc = t.description?.toLowerCase() ?? '';
                final src = t.sourceAccountNumber?.toLowerCase() ?? '';
                final dst = t.destinationAccountNumber?.toLowerCase() ?? '';
                final id = t.id.toLowerCase();
                final type = t.type.toLowerCase();
                final idemp = t.idempotencyKey.toLowerCase();
                return desc.contains(_searchQuery) ||
                    src.contains(_searchQuery) ||
                    dst.contains(_searchQuery) ||
                    id.contains(_searchQuery) ||
                    type.contains(_searchQuery) ||
                    idemp.contains(_searchQuery);
              }).toList();

        return RefreshIndicator(
          onRefresh: widget.viewModel.loadFirstPage,
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
                        if (widget.viewModel.pagination != null)
                          Text(
                            '${displayedItems.length} / ${widget.viewModel.pagination!.total}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: BankOsColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search input
                    SizedBox(
                      height: 44,
                      child: TextField(
                        key: const Key('history_search_field'),
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Buscar por concepto, cuenta o ID...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: BankOsColors.muted,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: BankOsColors.slateSoft,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: BankOsColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: BankOsColors.border),
                          ),
                        ),
                      ),
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
                            onTap: () => widget.viewModel.setTypeFilter(null),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            key: const Key('filter_deposit'),
                            label: 'Depósitos',
                            selected: selected == 'deposit',
                            onTap: () => widget.viewModel.setTypeFilter('deposit'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            key: const Key('filter_withdrawal'),
                            label: 'Retiros',
                            selected: selected == 'withdrawal',
                            onTap: () =>
                                widget.viewModel.setTypeFilter('withdrawal'),
                          ),
                          const SizedBox(width: 8),
                          _FilterPill(
                            key: const Key('filter_transfer'),
                            label: 'Transferencias',
                            selected: selected == 'transfer',
                            onTap: () => widget.viewModel.setTypeFilter('transfer'),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            key: const Key('filter_date_range_button'),
                            avatar: const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                            ),
                            label: Text(
                              dateRange == null
                                  ? 'Rango Fechas'
                                  : '${DateFormat('dd/MM').format(dateRange.start)} - ${DateFormat('dd/MM').format(dateRange.end)}',
                            ),
                            backgroundColor: dateRange != null
                                ? BankOsColors.navy.withValues(alpha: 0.1)
                                : null,
                            onPressed: () => _pickDateRange(context),
                          ),
                          if (dateRange != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => widget.viewModel.setDateRange(null),
                              tooltip: 'Quitar filtro de fechas',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (accountFilterLabel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: BankOsColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.filter_alt_rounded,
                                  size: 14,
                                  color: BankOsColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Cuenta: $accountFilterLabel',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: BankOsColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () =>
                                      widget.viewModel.setAccountFilter(null),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: BankOsColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: widget.viewModel.clearAllFilters,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Limpiar filtros'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),

              // List Body
              Expanded(
                child: widget.viewModel.isLoading &&
                        widget.viewModel.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : widget.viewModel.errorMessage != null &&
                            widget.viewModel.items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.viewModel.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: BankOsColors.crimson,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: widget.viewModel.loadFirstPage,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : displayedItems.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Icon(
                                    _searchQuery.isNotEmpty
                                        ? Icons.search_off_rounded
                                        : Icons.receipt_long_outlined,
                                    size: 48,
                                    color: BankOsColors.muted,
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No se encontraron transacciones para "$_searchQuery"'
                                          : 'No hay transacciones para este filtro.',
                                      style: const TextStyle(
                                        color: BankOsColors.muted,
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: const Text('Limpiar búsqueda'),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: displayedItems.length +
                                    (widget.viewModel.hasMore &&
                                            _searchQuery.isEmpty
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index == displayedItems.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: OutlinedButton(
                                        onPressed: widget.viewModel.isLoadingMore
                                            ? null
                                            : widget.viewModel.loadNextPage,
                                        child: widget.viewModel.isLoadingMore
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
                                    key: Key(
                                      'tx_card_${displayedItems[index].id}',
                                    ),
                                    tx: displayedItems[index],
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
  const _TransactionCard({super.key, required this.tx});

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

    return InkWell(
      onTap: () => TransactionDetailSheet.show(context, tx),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Idem: ${BankFormatters.shortUuid(tx.idempotencyKey)} · Corr: ${BankFormatters.shortUuid(tx.correlationId)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: BankOsColors.muted,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: BankOsColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
