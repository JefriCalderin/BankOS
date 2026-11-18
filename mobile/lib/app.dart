import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/banking_repository.dart';
import 'data/services/bankos_api_client.dart';
import 'data/services/secure_storage_service.dart';
import 'ui/core/theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/login_view.dart';
import 'ui/features/shell/views/home_shell_view.dart';

class BankOsMobileApp extends StatefulWidget {
  const BankOsMobileApp({
    super.key,
    this.apiClient,
    this.storage,
  });

  final BankOsApiClient? apiClient;
  final KeyValueStorage? storage;

  static String defaultApiBaseUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  @override
  State<BankOsMobileApp> createState() => _BankOsMobileAppState();
}

class _BankOsMobileAppState extends State<BankOsMobileApp> {
  late final BankOsApiClient _apiClient;
  late final KeyValueStorage _storage;
  late final AuthRepository _authRepository;
  late final BankingRepository _bankingRepository;
  late final AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ??
        BankOsApiClient(baseUrl: BankOsMobileApp.defaultApiBaseUrl());
    _storage = widget.storage ?? SecureStorageService();
    _authRepository = AuthRepository(
      apiClient: _apiClient,
      storage: _storage,
    );
    _bankingRepository = BankingRepository(
      apiClient: _apiClient,
      authRepository: _authRepository,
    );
    _authViewModel = AuthViewModel(
      authRepository: _authRepository,
      apiClient: _apiClient,
    )..initialize();
  }

  @override
  void dispose() {
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankOS Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildBankOsTheme(),
      home: ListenableBuilder(
        listenable: _authViewModel,
        builder: (context, _) {
          if (_authViewModel.isInitializing) {
            return const Scaffold(
              backgroundColor: BankOsColors.navy,
              body: Center(
                child: CircularProgressIndicator(color: BankOsColors.emerald),
              ),
            );
          }

          final session = _authViewModel.session;
          if (session == null) {
            return LoginView(viewModel: _authViewModel);
          }

          return HomeShellView(
            key: ValueKey('${session.tenant.id}:${session.user.id}'),
            session: session,
            authViewModel: _authViewModel,
            authRepository: _authRepository,
            bankingRepository: _bankingRepository,
          );
        },
      ),
    );
  }
}
