import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';
import 'theme.dart';

/// Local Two-Factor Authentication modal requiring either a 4-digit security PIN
/// or simulated Biometric verification before authorizing sensitive financial
/// operations (transfers & withdrawals).
class SecurityAuthDialog extends StatefulWidget {
  const SecurityAuthDialog({
    super.key,
    required this.authRepository,
    required this.operationLabel,
    required this.amountLabel,
  });

  final AuthRepository authRepository;
  final String operationLabel;
  final String amountLabel;

  static Future<bool> verify({
    required BuildContext context,
    required AuthRepository authRepository,
    required String operationLabel,
    required String amountLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecurityAuthDialog(
        authRepository: authRepository,
        operationLabel: operationLabel,
        amountLabel: amountLabel,
      ),
    );
    return result == true;
  }

  @override
  State<SecurityAuthDialog> createState() => _SecurityAuthDialogState();
}

class _SecurityAuthDialogState extends State<SecurityAuthDialog> {
  final _pinController = TextEditingController();
  bool _biometricAvailable = true;
  bool _scanningBiometric = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final enabled = await widget.authRepository.isBiometricEnabled();
    if (mounted) {
      setState(() => _biometricAvailable = enabled);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'Ingrese un PIN de 4 dígitos');
      return;
    }
    final valid = await widget.authRepository.verifyPin(pin);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'PIN incorrecto (PIN demo por defecto: 1234)');
    }
  }

  Future<void> _simulateBiometric() async {
    setState(() {
      _scanningBiometric = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BankOsColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: BankOsColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Autorización 2FA Local',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: BankOsColors.navy,
                      ),
                    ),
                    Text(
                      '${widget.operationLabel} • ${widget.amountLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: BankOsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('pin_2fa_field'),
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 12,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'PIN de seguridad (4 dígitos)',
              helperText: 'PIN demo por defecto: 1234',
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _submitPin(),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('confirm_pin_2fa_button'),
            onPressed: _scanningBiometric ? null : _submitPin,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Autorizar con PIN'),
          ),
          if (_biometricAvailable) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('biometric_2fa_button'),
              onPressed: _scanningBiometric ? null : _simulateBiometric,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _scanningBiometric
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint_rounded),
              label: Text(
                _scanningBiometric
                    ? 'Verificando huella / FaceID...'
                    : 'Autorizar con Biometría (Simulada)',
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
