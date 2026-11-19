import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../view_models/auth_view_model.dart';
import 'tenant_registration_dialog.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: BankOsColors.primaryGradient,
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Header (Figma BankOS Style)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: BankOsColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'BankOS Cloud',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    Text(
                                      'Banca Multitenant como Servicio',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'Tenant Isolated',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Main Card with White Elevation (Figma Banking design)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Welcome Back',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: BankOsColors.navy,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Ingreso por institución financiera y rol asignado',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: BankOsColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Demo Presets
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ActionChip(
                                        avatar: const Icon(
                                          Icons.person_outline,
                                          size: 16,
                                          color: BankOsColors.primary,
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
                                          color: BankOsColors.amber,
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
                                          color: BankOsColors.emerald,
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

                                  const SizedBox(height: 20),

                                  // Tenant Slug
                                  TextFormField(
                                    key: const Key('tenant_slug_field'),
                                    controller: _tenantController,
                                    decoration: InputDecoration(
                                      labelText: 'Identificador / Slug del Tenant',
                                      hintText: 'ej. banco-andes',
                                      prefixIcon: const Icon(Icons.domain_rounded, color: BankOsColors.primary),
                                      suffixIcon: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: BankOsColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'tenant_id',
                                          style: TextStyle(
                                            color: BankOsColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'El tenant slug es obligatorio'
                                            : null,
                                  ),

                                  const SizedBox(height: 14),

                                  // Email
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

                                  // Password
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

                                  const SizedBox(height: 20),

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
                                        : const Text('Iniciar Sesión en Tenant'),
                                  ),

                                  const SizedBox(height: 14),

                                  // Security callout
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F5FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFD6E4FF)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.shield_outlined, color: BankOsColors.primary, size: 18),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Aislamiento estricto de datos por tenant garantizado.',
                                            style: TextStyle(
                                              color: BankOsColors.primaryDark,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  OutlinedButton.icon(
                                    key: const Key('register_tenant_button'),
                                    onPressed: widget.viewModel.isLoading
                                        ? null
                                        : () => TenantRegistrationDialog.show(
                                              context,
                                              widget.viewModel,
                                            ),
                                    icon: const Icon(Icons.add_business_rounded, size: 18),
                                    label: const Text('Registrar Nueva Institución'),
                                  ),

                                  const SizedBox(height: 10),

                                  TextButton.icon(
                                    onPressed: () => setState(
                                      () => _showServerSettings =
                                          !_showServerSettings,
                                    ),
                                    icon: const Icon(Icons.dns_outlined, size: 18),
                                    label: Text(
                                      _showServerSettings
                                          ? 'Ocultar configuración de servidor'
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
      ),
    );
  }
}
