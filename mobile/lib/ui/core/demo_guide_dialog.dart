import 'package:flutter/material.dart';

import '../../data/repositories/banking_repository.dart';
import '../features/admin/views/webhooks_viewer_sheet.dart';
import '../features/auth/view_models/auth_view_model.dart';
import 'theme.dart';

class DemoGuideDialog extends StatelessWidget {
  const DemoGuideDialog({
    super.key,
    required this.authViewModel,
    required this.bankingRepository,
    required this.currentTenantSlug,
  });

  final AuthViewModel authViewModel;
  final BankingRepository bankingRepository;
  final String currentTenantSlug;

  static Future<void> show(
    BuildContext context, {
    required AuthViewModel authViewModel,
    required BankingRepository bankingRepository,
    required String currentTenantSlug,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DemoGuideDialog(
        authViewModel: authViewModel,
        bankingRepository: bankingRepository,
        currentTenantSlug: currentTenantSlug,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: BankOsColors.amber,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guía de Demostración Hackatón',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: BankOsColors.navy,
                          ),
                        ),
                        Text(
                          '3 Escenarios Críticos de Evaluación',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: BankOsColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    // Scenario 1
                    _ScenarioCard(
                      number: '1',
                      title: 'Aislamiento Estricto Multitenant',
                      description:
                          'Demuestra que dos instituciones bancarias operan en paralelo sin cruce ni filtración de datos.',
                      accentColor: BankOsColors.primary,
                      actions: [
                        const Text(
                          'Cambio rápido de Tenant para los jueces:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BankOsColors.slate,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilledButton.tonal(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await authViewModel.login(
                                  tenantSlug: 'banco-andes',
                                  email: 'ana@andes.bank',
                                  password: 'Cliente123!',
                                );
                              },
                              child: const Text('Entrar a Banco Andes (Ana)'),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await authViewModel.login(
                                  tenantSlug: 'cooperativa-sol',
                                  email: 'maria@sol.coop',
                                  password: 'Cliente123!',
                                );
                              },
                              child: const Text('Entrar a Coop Sol (María)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Scenario 2
                    _ScenarioCard(
                      number: '2',
                      title: 'Idempotencia: Reintento sin Doble Cobro',
                      description:
                          'En la pantalla de "Resumen Pre-Transacción", activa el switch "Simular pérdida de red". La app capturará la desconexión y ofrecerá un botón para reintentar con exactamente la misma Idempotency-Key. El backend responderá con la misma transacción original sin debitar de nuevo.',
                      accentColor: BankOsColors.amber,
                    ),
                    const SizedBox(height: 12),

                    // Scenario 3
                    _ScenarioCard(
                      number: '3',
                      title: 'Transferencia Multimoneda + Comisión + Webhook',
                      description:
                          'Transfiere de USD a COP en Banco de los Andes: se aplica automáticamente la comisión del 1.5% y la tasa estática 4000. Al completarse, se dispara un webhook asíncrono con firma HMAC.',
                      accentColor: BankOsColors.emerald,
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            WebhooksViewerSheet.show(
                              context,
                              bankingRepository: bankingRepository,
                              tenantName: currentTenantSlug,
                            );
                          },
                          icon: const Icon(Icons.webhook_rounded, size: 16),
                          label: const Text('Ver Webhooks en Vivo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.number,
    required this.title,
    required this.description,
    required this.accentColor,
    this.actions,
  });

  final String number;
  final String title;
  final String description;
  final Color accentColor;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              CircleAvatar(
                radius: 12,
                backgroundColor: accentColor,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BankOsColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12.5,
              color: BankOsColors.slate,
              height: 1.35,
            ),
          ),
          if (actions != null) ...[
            const SizedBox(height: 10),
            ...actions!,
          ],
        ],
      ),
    );
  }
}
