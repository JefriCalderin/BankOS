import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../view_models/auth_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key, required this.viewModel});

  final AuthViewModel viewModel;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController(text: 'banco-andes');
  final _emailController = TextEditingController(text: 'ana@andes.bank');
  final _passwordController = TextEditingController(text: 'Cliente123!');
  late final TextEditingController _apiUrlController;
  bool _obscurePassword = true;
  bool _showServerSettings = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: widget.viewModel.currentApiUrl,
    );
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  void _applyPreset({
    required String slug,
    required String email,
    required String password,
  }) {
    setState(() {
      _tenantController.text = slug;
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.viewModel.updateApiUrl(_apiUrlController.text);
    await widget.viewModel.login(
      tenantSlug: _tenantController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BankOsColors.navy,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: BankOsColors.emerald,
                            child: Icon(
                              Icons.account_balance_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BankOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Banca Multitenant como Servicio',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Ingreso por Institución',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: BankOsColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Selecciona o ingresa el slug de tu banco/cooperativa.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: BankOsColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.person_outline,
                                        size: 16,
                                      ),
                                      label: const Text('Andes · Ana'),
                                      onPressed: () => _applyPreset(
                                        slug: 'banco-andes',
                                        email: 'ana@andes.bank',
                                        password: 'Cliente123!',
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Andes · Admin'),
                                      onPressed: () => _applyPreset(
                                        slug: 'banco-andes',
                                        email: 'admin@andes.bank',
                                        password: 'Admin123!',
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.business_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Coop Sol · María'),
                                      onPressed: () => _applyPreset(
                                        slug: 'cooperativa-sol',
                                        email: 'maria@sol.coop',
                                        password: 'Cliente123!',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  key: const Key('tenant_slug_field'),
                                  controller: _tenantController,
                                  decoration: const InputDecoration(
                                    labelText: 'Identificador / Slug del Tenant',
                                    hintText: 'ej. banco-andes',
                                    prefixIcon: Icon(Icons.domain_rounded),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'El tenant slug es obligatorio'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const Key('email_field'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Correo electrónico',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Ingrese un correo válido'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const Key('password_field'),
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'Ingrese su contraseña'
                                          : null,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                if (widget.viewModel.errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: BankOsColors.crimsonSoft,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: BankOsColors.crimson
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: BankOsColors.crimson,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.viewModel.errorMessage!,
                                            style: const TextStyle(
                                              color: BankOsColors.crimson,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                FilledButton(
                                  key: const Key('login_submit_button'),
                                  onPressed: widget.viewModel.isLoading
                                      ? null
                                      : _submit,
                                  child: widget.viewModel.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Iniciar Sesión'),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showServerSettings =
                                        !_showServerSettings,
                                  ),
                                  icon: const Icon(Icons.dns_outlined, size: 18),
                                  label: Text(
                                    _showServerSettings
                                        ? 'Ocultar configuración del servidor'
                                        : 'Configurar URL del Backend',
                                  ),
                                ),
                                if (_showServerSettings) ...[
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _apiUrlController,
                                    decoration: const InputDecoration(
                                      labelText: 'URL base API BankOS',
                                      hintText: 'http://10.0.2.2:8080',
                                      helperText:
                                          'Emulador Android: http://10.0.2.2:8080 · Web/Local: http://localhost:8080',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
