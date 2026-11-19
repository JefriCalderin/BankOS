import 'package:flutter/material.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/banking_repository.dart';
import '../../../../domain/models/bank_models.dart';
import '../../../core/demo_guide_dialog.dart';
import '../../../core/theme.dart';
import '../../admin/view_models/admin_view_model.dart';
import '../../admin/views/admin_view.dart';
import '../../admin/views/webhooks_viewer_sheet.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../history/view_models/history_view_model.dart';
import '../../history/views/history_view.dart';
import '../../operations/view_models/operations_view_model.dart';
import '../../operations/views/operations_view.dart';

class HomeShellView extends StatefulWidget {
  const HomeShellView({
    super.key,
    required this.session,
    required this.authViewModel,
    required this.authRepository,
    required this.bankingRepository,
  });

  final UserSession session;
  final AuthViewModel authViewModel;
  final AuthRepository authRepository;
  final BankingRepository bankingRepository;

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  int _selectedIndex = 0;
  BankAccount? _preselectedAccount;

  late final DashboardViewModel _dashboardVm;
  late final OperationsViewModel _operationsVm;
  late final HistoryViewModel _historyVm;
  late final AdminViewModel _adminVm;

  @override
  void initState() {
    super.initState();
    _dashboardVm = DashboardViewModel(
      bankingRepository: widget.bankingRepository,
    );
    _operationsVm = OperationsViewModel(
      bankingRepository: widget.bankingRepository,
    );
    _historyVm = HistoryViewModel(
      bankingRepository: widget.bankingRepository,
    );
    _adminVm = AdminViewModel(
      bankingRepository: widget.bankingRepository,
    );

    _refreshAll();
  }

  @override
  void dispose() {
    _dashboardVm.dispose();
    _operationsVm.dispose();
    _historyVm.dispose();
    _adminVm.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _dashboardVm.loadAccounts(),
      _historyVm.loadFirstPage(),
      if (widget.session.user.isAdmin) _adminVm.loadAdminData(),
    ]);
  }

  Future<void> _openSecuritySettings() async {
    final pinController = TextEditingController();
    var biometricEnabled = await widget.authRepository.isBiometricEnabled();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Seguridad Local (2FA)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    maxLength: 4,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo PIN de 4 dígitos',
                      hintText: 'ej. 4321',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Habilitar Biometría simulada'),
                    value: biometricEnabled,
                    onChanged: (v) async {
                      await widget.authRepository.setBiometricEnabled(v);
                      setDialogState(() => biometricEnabled = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newPin = pinController.text.trim();
                    final messenger = ScaffoldMessenger.of(context);
                    if (newPin.length == 4) {
                      await widget.authRepository.setLocalPin(newPin);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('PIN de seguridad actualizado'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar PIN'),
                ),
              ],
            );
          },
        );
      },
    );
    pinController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.session.user.isAdmin;

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Cuentas',
      ),
      const NavigationDestination(
        icon: Icon(Icons.swap_horiz_rounded),
        selectedIcon: Icon(Icons.swap_horizontal_circle_rounded),
        label: 'Operar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Historial',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.account_balance_rounded,
              color: BankOsColors.emerald,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'BankOS · ${widget.session.tenant.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Monitor Webhooks',
            icon: const Icon(Icons.sensors_rounded),
            onPressed: () {
              WebhooksViewerSheet.show(
                context,
                bankingRepository: widget.bankingRepository,
                tenantName: widget.session.tenant.name,
              );
            },
          ),
          IconButton(
            tooltip: 'Guía Demo Hackatón',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              DemoGuideDialog.show(
                context,
                authViewModel: widget.authViewModel,
                bankingRepository: widget.bankingRepository,
                currentTenantSlug: widget.session.tenant.slug,
              );
            },
          ),
          IconButton(
            tooltip: 'Seguridad 2FA (PIN / Biometría)',
            icon: const Icon(Icons.security_rounded),
            onPressed: _openSecuritySettings,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.authViewModel.logout,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _dashboardVm,
        builder: (context, _) {
          final pages = <Widget>[
            DashboardView(
              session: widget.session,
              viewModel: _dashboardVm,
              onQuickOperation: (kind, account) {
                _operationsVm.selectKind(kind);
                setState(() {
                  _preselectedAccount = account;
                  _selectedIndex = 1;
                });
              },
              onViewAccountTransactions: (account) {
                _historyVm.setAccountFilter(account.accountNumber);
                setState(() {
                  _selectedIndex = 2;
                });
              },
            ),
            OperationsView(
              accounts: _dashboardVm.accounts,
              viewModel: _operationsVm,
              authRepository: widget.authRepository,
              initialAccount: _preselectedAccount,
              onOperationCompleted: () {
                _dashboardVm.loadAccounts();
                _historyVm.loadFirstPage();
              },
            ),
            HistoryView(viewModel: _historyVm),
            if (isAdmin)
              AdminView(
                session: widget.session,
                accounts: _dashboardVm.accounts,
                viewModel: _adminVm,
                onDataMutated: () {
                  widget.authViewModel.refreshCachedSession();
                  _dashboardVm.loadAccounts();
                },
              ),
          ];

          final safeIndex = _selectedIndex.clamp(0, pages.length - 1);
          return IndexedStack(index: safeIndex, children: pages);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
        onDestinationSelected: (idx) {
          setState(() => _selectedIndex = idx);
          if (idx == 0) _dashboardVm.loadAccounts();
          if (idx == 2) _historyVm.loadFirstPage();
          if (idx == 3 && isAdmin) _adminVm.loadAdminData();
        },
        destinations: destinations,
      ),
    );
  }
}
