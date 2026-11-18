import 'package:flutter/material.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../view_models/operations_view_model.dart';
import 'pre_transaction_summary_view.dart';

class OperationsView extends StatefulWidget {
  const OperationsView({
    super.key,
    required this.accounts,
    required this.viewModel,
    required this.authRepository,
    required this.onOperationCompleted,
    this.initialAccount,
  });

  final List<BankAccount> accounts;
  final OperationsViewModel viewModel;
  final AuthRepository authRepository;
  final VoidCallback onOperationCompleted;
  final BankAccount? initialAccount;

  @override
  State<OperationsView> createState() => _OperationsViewState();
}

class _OperationsViewState extends State<OperationsView> {
  final _amountController = TextEditingController();
  final _destAccountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedSourceAccountNumber;

  List<BankAccount> get _activeAccounts =>
      widget.accounts.where((a) => a.isActive).toList();

  @override
  void initState() {
    super.initState();
    _syncDefaultAccount();
  }

  @override
  void didUpdateWidget(covariant OperationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAccount != null &&
        widget.initialAccount != oldWidget.initialAccount) {
      _selectedSourceAccountNumber = widget.initialAccount!.accountNumber;
    } else {
      _syncDefaultAccount();
    }
  }

  void _syncDefaultAccount() {
    final active = _activeAccounts;
    if (active.isEmpty) {
      _selectedSourceAccountNumber = null;
      return;
    }
    final exists =
        active.any((a) => a.accountNumber == _selectedSourceAccountNumber);
    if (!exists) {
      _selectedSourceAccountNumber =
          widget.initialAccount?.accountNumber ?? active.first.accountNumber;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _destAccountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  BankAccount? get _selectedAccount {
    for (final a in _activeAccounts) {
      if (a.accountNumber == _selectedSourceAccountNumber) return a;
    }
    return null;
  }

  Future<void> _goToSummary() async {
    final source = _selectedAccount;
    if (source == null) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un monto numérico positivo')),
      );
      return;
    }

    final draft = await widget.viewModel.prepareDraft(
      kind: widget.viewModel.selectedKind,
      sourceAccount: source,
      amount: amount,
      destinationAccountNumber:
          widget.viewModel.selectedKind == OperationKind.transfer
              ? _destAccountController.text.trim()
              : null,
      description: _descriptionController.text.trim(),
    );

    if (draft == null || !mounted) return;

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreTransactionSummaryView(
          viewModel: widget.viewModel,
          authRepository: widget.authRepository,
          onOperationCompleted: widget.onOperationCompleted,
        ),
      ),
    );

    if (completed == true) {
      _amountController.clear();
      _descriptionController.clear();
      widget.viewModel.clearDestination();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final active = _activeAccounts;
        final kind = widget.viewModel.selectedKind;
        final lookup = widget.viewModel.destinationLookup;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Operaciones Financieras',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: BankOsColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Todas las operaciones utilizan Idempotency-Key y X-Correlation-ID.',
              style: TextStyle(fontSize: 13, color: BankOsColors.muted),
            ),
            const SizedBox(height: 16),

            // Segmented operation selector
            SegmentedButton<OperationKind>(
              segments: const [
                ButtonSegment(
                  value: OperationKind.deposit,
                  label: Text('Depósito'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: OperationKind.withdrawal,
                  label: Text('Retiro'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: OperationKind.transfer,
                  label: Text('Transferir'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (set) =>
                  widget.viewModel.selectKind(set.first),
            ),
            const SizedBox(height: 18),

            if (active.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No dispones de cuentas activas para operar.',
                    style: TextStyle(color: BankOsColors.crimson),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedSourceAccountNumber),
                        initialValue: _selectedSourceAccountNumber,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: kind == OperationKind.deposit
                              ? 'Cuenta a abonar'
                              : 'Cuenta de origen',
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                        ),
                        items: active.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.accountNumber,
                            child: Text(
                              '${acc.accountNumber} · ${BankFormatters.money(acc.balance, acc.currency)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedSourceAccountNumber = val),
                      ),
                      const SizedBox(height: 16),

                      // Destination lookup for transfers
                      if (kind == OperationKind.transfer) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('dest_account_field'),
                                controller: _destAccountController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'N° Cuenta Destino',
                                  hintText: 'ej. AND-COP-2001',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                                onChanged: (_) {
                                  if (lookup != null) {
                                    widget.viewModel.clearDestination();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                key: const Key('lookup_dest_button'),
                                onPressed: widget.viewModel.isLookingUp
                                    ? null
                                    : () => widget.viewModel.lookupDestination(
                                          _destAccountController.text,
                                        ),
                                child: widget.viewModel.isLookingUp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Buscar'),
                              ),
                            ),
                          ],
                        ),
                        if (lookup != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lookup.isActive
                                  ? BankOsColors.emeraldSoft
                                  : BankOsColors.crimsonSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  lookup.isActive
                                      ? Icons.check_circle_rounded
                                      : Icons.block_rounded,
                                  color: lookup.isActive
                                      ? BankOsColors.emerald
                                      : BankOsColors.crimson,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lookup.ownerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: BankOsColors.navy,
                                        ),
                                      ),
                                      Text(
                                        '${lookup.accountNumber} · Divisa: ${lookup.currency} · Estado: ${lookup.status}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: BankOsColors.slate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],

                      TextField(
                        key: const Key('amount_field'),
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Monto (${_selectedAccount?.currency ?? ''})',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Concepto / Descripción (opcional)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),

                      if (widget.viewModel.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: BankOsColors.crimsonSoft,
                            borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(height: 20),

                      FilledButton.icon(
                        key: const Key('continue_to_summary_button'),
                        onPressed:
                            widget.viewModel.isQuoting ? null : _goToSummary,
                        icon: widget.viewModel.isQuoting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.summarize_rounded),
                        label: const Text('Ver Resumen Pre-Transacción'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
