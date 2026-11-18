import 'package:flutter/material.dart';

import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../view_models/admin_view_model.dart';

class AdminView extends StatefulWidget {
  const AdminView({
    super.key,
    required this.session,
    required this.accounts,
    required this.viewModel,
    required this.onDataMutated,
  });

  final UserSession session;
  final List<BankAccount> accounts;
  final AdminViewModel viewModel;
  final VoidCallback onDataMutated;

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  late final TextEditingController _limitController;
  late final TextEditingController _feeValueController;
  late final TextEditingController _webhookController;
  late String _feeType;

  String? _selectedUserId;
  String _newAccountCurrency = 'USD';
  final _initialBalanceController = TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.tenant.config;
    _limitController =
        TextEditingController(text: cfg.maxTransactionLimit.toString());
    _feeValueController =
        TextEditingController(text: cfg.transferFeeValue.toString());
    _webhookController = TextEditingController(text: cfg.webhookUrl ?? '');
    _feeType = cfg.transferFeeType;
  }

  @override
  void dispose() {
    _limitController.dispose();
    _feeValueController.dispose();
    _webhookController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final limit = double.tryParse(_limitController.text.trim());
    final fee = double.tryParse(_feeValueController.text.trim());
    if (limit == null || fee == null) return;

    final ok = await widget.viewModel.saveTenantConfig(
      maxTransactionLimit: limit,
      transferFeeType: _feeType,
      transferFeeValue: fee,
      webhookUrl: _webhookController.text.trim(),
    );
    if (ok) widget.onDataMutated();
  }

  Future<void> _createAccount() async {
    final ownerId =
        _selectedUserId ?? widget.viewModel.users.firstOrNull?.id;
    if (ownerId == null) return;
    final bal = double.tryParse(_initialBalanceController.text.trim()) ?? 0;

    final ok = await widget.viewModel.createAccount(
      ownerUserId: ownerId,
      currency: _newAccountCurrency,
      initialBalance: bal,
    );
    if (ok) widget.onDataMutated();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final users = widget.viewModel.users;
        if (_selectedUserId == null && users.isNotEmpty) {
          _selectedUserId = users.first.id;
        }

        return RefreshIndicator(
          onRefresh: widget.viewModel.loadAdminData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Administración del Tenant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: BankOsColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.session.tenant.name} (${widget.session.tenant.slug})',
                style: const TextStyle(color: BankOsColors.muted),
              ),
              if (widget.viewModel.statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BankOsColors.emeraldSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.viewModel.statusMessage!,
                    style: const TextStyle(
                      color: BankOsColors.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (widget.viewModel.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BankOsColors.crimsonSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.viewModel.errorMessage!,
                    style: const TextStyle(color: BankOsColors.crimson),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Tenant Parameters Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Parámetros Financieros & Webhook',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: BankOsColors.navy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _limitController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              'Límite máximo por transacción (${widget.session.tenant.config.baseCurrency})',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _feeType,
                              decoration: const InputDecoration(
                                labelText: 'Tipo comisión',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'percentage',
                                  child: Text('Porcentual (%)'),
                                ),
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('Fija'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _feeType = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _feeValueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Valor comisión',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _webhookController,
                        decoration: const InputDecoration(
                          labelText: 'Webhook URL (Notificaciones POST)',
                          hintText: 'http://webhook-sink:8085/webhook',
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed:
                            widget.viewModel.isLoading ? null : _saveConfig,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Guardar Configuración'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Create Account Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Crear Cuenta Bancaria',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: BankOsColors.navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (users.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUserId,
                          decoration: const InputDecoration(
                            labelText: 'Titular de la cuenta',
                          ),
                          items: users.map((u) {
                            return DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.fullName} (${u.email})'),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedUserId = v),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _newAccountCurrency,
                              decoration:
                                  const InputDecoration(labelText: 'Moneda'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'COP',
                                  child: Text('COP'),
                                ),
                                DropdownMenuItem(
                                  value: 'USD',
                                  child: Text('USD'),
                                ),
                                DropdownMenuItem(
                                  value: 'EUR',
                                  child: Text('EUR'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _newAccountCurrency = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _initialBalanceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Saldo inicial',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed:
                            widget.viewModel.isLoading ? null : _createAccount,
                        icon: const Icon(Icons.add_card_rounded),
                        label: const Text('Crear Cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Account Soft-Delete Management
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Control de Cuentas (Borrado Lógico)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: BankOsColors.navy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.accounts.map((acc) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${acc.accountNumber} (${acc.currency})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${acc.ownerName} · Estado: ${acc.status}',
                          ),
                          trailing: OutlinedButton(
                            onPressed: widget.viewModel.isLoading
                                ? null
                                : () async {
                                    final ok = await widget.viewModel
                                        .toggleAccountSoftDelete(acc);
                                    if (ok) widget.onDataMutated();
                                  },
                            child: Text(
                              acc.isActive ? 'Desactivar' : 'Reactivar',
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Immutable Audit Log
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.history_edu_rounded,
                            color: BankOsColors.navy,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Auditoría Inmutable (Solo Lectura)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: BankOsColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (widget.viewModel.auditLogs.isEmpty)
                        const Text(
                          'Sin registros de auditoría.',
                          style: TextStyle(color: BankOsColors.muted),
                        )
                      else
                        ...widget.viewModel.auditLogs.map((log) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: BankOsColors.navy
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        log.action,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: BankOsColors.navy,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      BankFormatters.dateTime(log.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: BankOsColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Actor: ${log.actorEmail} · ${log.entityType}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: BankOsColors.slate,
                                  ),
                                ),
                                const Divider(height: 12),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
