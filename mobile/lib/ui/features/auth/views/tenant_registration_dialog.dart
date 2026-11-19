import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../view_models/auth_view_model.dart';

class TenantRegistrationDialog extends StatefulWidget {
  const TenantRegistrationDialog({super.key, required this.viewModel});

  final AuthViewModel viewModel;

  static Future<bool?> show(BuildContext context, AuthViewModel viewModel) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantRegistrationDialog(viewModel: viewModel),
    );
  }

  @override
  State<TenantRegistrationDialog> createState() =>
      _TenantRegistrationDialogState();
}

class _TenantRegistrationDialogState extends State<TenantRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController =
      TextEditingController(text: 'Fintech Nueva Era');
  final _slugController =
      TextEditingController(text: 'fintech-nueva-era');
  final _limitController = TextEditingController(text: '20000000');
  final _feeValueController = TextEditingController(text: '1.25');
  final _webhookUrlController =
      TextEditingController(text: 'http://webhook-sink:8085/webhook');

  final _adminNameController =
      TextEditingController(text: 'Directora Laura Pardo');
  final _adminEmailController =
      TextEditingController(text: 'admin@nuevaera.bank');
  final _adminPasswordController =
      TextEditingController(text: 'Admin123!');

  String _baseCurrency = 'COP';
  String _feeType = 'percentage';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _limitController.dispose();
    _feeValueController.dispose();
    _webhookUrlController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(_limitController.text.trim()) ?? 10000000;
    final fee = double.tryParse(_feeValueController.text.trim()) ?? 1.0;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final defaultRates = <String, double>{
      'USD_COP': 4150.0,
      'COP_USD': 0.00024,
      'EUR_USD': 1.09,
      'USD_EUR': 0.917,
    };

    final ok = await widget.viewModel.registerTenant(
      name: _nameController.text.trim(),
      slug: _slugController.text.trim().toLowerCase(),
      baseCurrency: _baseCurrency,
      maxTransactionLimit: limit,
      transferFeeType: _feeType,
      transferFeeValue: fee,
      exchangeRates: defaultRates,
      adminEmail: _adminEmailController.text.trim(),
      adminFullName: _adminNameController.text.trim(),
      adminPassword: _adminPasswordController.text,
      webhookUrl: _webhookUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = widget.viewModel.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: BankOsColors.primary,
                      child: Icon(Icons.business_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alta de Nueva Institución',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: BankOsColors.navy,
                            ),
                          ),
                          Text(
                            'Nuevo tenant aislado en BankOS',
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
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: 24),

                const Text(
                  '1. Datos de la Institución',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: BankOsColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la institución',
                    hintText: 'ej. Fintech Nueva Era',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Identificador único / Slug',
                    hintText: 'ej. fintech-nueva-era',
                    helperText: 'Letras minúsculas, números y guiones',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _baseCurrency,
                        decoration:
                            const InputDecoration(labelText: 'Moneda principal'),
                        items: const [
                          DropdownMenuItem(value: 'COP', child: Text('COP')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _baseCurrency = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _limitController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Límite máx/tx'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _feeType,
                        decoration:
                            const InputDecoration(labelText: 'Comisión tipo'),
                        items: const [
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Porcentual'),
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
                      child: TextFormField(
                        controller: _feeValueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Comisión valor'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _webhookUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Webhook URL (Opcional)',
                    hintText: 'http://webhook-sink:8085/webhook',
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  '2. Usuario Administrador Inicial',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: BankOsColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _adminNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Administrador',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _adminEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del Administrador',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _adminPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (mínimo 6 caracteres)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BankOsColors.crimsonSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: BankOsColors.crimson,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('submit_tenant_button'),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Dar de Alta y Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
