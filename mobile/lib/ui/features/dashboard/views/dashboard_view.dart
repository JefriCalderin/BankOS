import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/bank_models.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../view_models/dashboard_view_model.dart';
import 'exchange_rates_sheet.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.session,
    required this.viewModel,
    required this.onQuickOperation,
    this.onViewAccountTransactions,
  });

  final UserSession session;
  final DashboardViewModel viewModel;
  final void Function(OperationKind kind, BankAccount? account)
      onQuickOperation;
  final void Function(BankAccount account)? onViewAccountTransactions;

  @override
  Widget build(BuildContext context) {
    final tenant = session.tenant;
    final feeLabel = tenant.config.transferFeeType == 'percentage'
        ? '${tenant.config.transferFeeValue}%'
        : BankFormatters.money(
            tenant.config.transferFeeValue,
            tenant.config.baseCurrency,
          );

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: viewModel.loadAccounts,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Tenant Header Card (Figma Banking Style)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: BankOsColors.darkCardGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tenant.slug.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: session.user.isAdmin
                                ? BankOsColors.amber
                                : BankOsColors.emerald,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            session.user.role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Hola, ${session.user.fullName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenant.name,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _TenantStatChip(
                          icon: Icons.currency_exchange_rounded,
                          label: 'Base: ${tenant.config.baseCurrency} · Ver FX',
                          onTap: () => ExchangeRatesSheet.show(
                            context,
                            tenant: tenant,
                            onOpenTransfer: () => onQuickOperation(
                              OperationKind.transfer,
                              viewModel.activeAccounts.firstOrNull,
                            ),
                          ),
                        ),
                        _TenantStatChip(
                          icon: Icons.percent_rounded,
                          label: 'Comisión: $feeLabel',
                        ),
                        _TenantStatChip(
                          icon: Icons.shield_outlined,
                          label:
                              'Límite: ${BankFormatters.money(tenant.config.maxTransactionLimit, tenant.config.baseCurrency)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Operations Row
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Depositar',
                      color: BankOsColors.emerald,
                      onTap: () => onQuickOperation(
                        OperationKind.deposit,
                        viewModel.activeAccounts.firstOrNull,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Retirar',
                      color: BankOsColors.amber,
                      onTap: () => onQuickOperation(
                        OperationKind.withdrawal,
                        viewModel.activeAccounts.firstOrNull,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transferir',
                      color: BankOsColors.primary,
                      onTap: () => onQuickOperation(
                        OperationKind.transfer,
                        viewModel.activeAccounts.firstOrNull,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionButton(
                      key: const Key('quick_action_exchange_rates'),
                      icon: Icons.currency_exchange_rounded,
                      label: 'Tasas FX',
                      color: BankOsColors.violet,
                      onTap: () => ExchangeRatesSheet.show(
                        context,
                        tenant: tenant,
                        onOpenTransfer: () => onQuickOperation(
                          OperationKind.transfer,
                          viewModel.activeAccounts.firstOrNull,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.user.isAdmin
                          ? 'Cuentas de la Institución'
                          : 'Mis Cuentas Bancarias',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: BankOsColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${viewModel.accounts.length} cuenta(s)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: BankOsColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (viewModel.isLoading && viewModel.accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (viewModel.errorMessage != null)
                Card(
                  color: BankOsColors.crimsonSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          viewModel.errorMessage!,
                          style: const TextStyle(color: BankOsColors.crimson),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: viewModel.loadAccounts,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (viewModel.accounts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No tienes cuentas registradas aún en esta institución.',
                        style: TextStyle(color: BankOsColors.muted),
                      ),
                    ),
                  ),
                )
              else
                ...viewModel.accounts.map(
                  (account) => _AccountCard(
                    account: account,
                    onCopy: () {
                      Clipboard.setData(
                        ClipboardData(text: account.accountNumber),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cuenta ${account.accountNumber} copiada',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    onTransferFrom: account.isActive
                        ? () => onQuickOperation(OperationKind.transfer, account)
                        : null,
                    onViewTransactions: onViewAccountTransactions != null
                        ? () => onViewAccountTransactions!(account)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TenantStatChip extends StatelessWidget {
  const _TenantStatChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white70,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: chip,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BankOsColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: BankOsColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onCopy,
    this.onTransferFrom,
    this.onViewTransactions,
  });

  final BankAccount account;
  final VoidCallback onCopy;
  final VoidCallback? onTransferFrom;
  final VoidCallback? onViewTransactions;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        account.isActive ? BankOsColors.emerald : BankOsColors.crimson;
    final statusBg =
        account.isActive ? BankOsColors.emeraldSoft : BankOsColors.crimsonSoft;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: BankOsColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    account.currency,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: BankOsColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.accountNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: BankOsColors.navy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    account.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              BankFormatters.money(account.balance, account.currency),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: BankOsColors.navy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Titular: ${account.ownerName}',
              style: const TextStyle(
                fontSize: 13,
                color: BankOsColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copiar N°'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (onTransferFrom != null)
                  TextButton.icon(
                    onPressed: onTransferFrom,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Transferir'),
                  ),
                if (onViewTransactions != null)
                  TextButton.icon(
                    onPressed: onViewTransactions,
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Movimientos'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
