import 'package:uuid/uuid.dart';

class TenantConfig {
  const TenantConfig({
    required this.maxTransactionLimit,
    required this.transferFeeType,
    required this.transferFeeValue,
    required this.baseCurrency,
    required this.exchangeRates,
    this.webhookUrl,
  });

  final double maxTransactionLimit;
  final String transferFeeType; // 'fixed' | 'percentage'
  final double transferFeeValue;
  final String baseCurrency;
  final Map<String, double> exchangeRates;
  final String? webhookUrl;

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final rawRates = json['exchange_rates'];
    final rates = <String, double>{};
    if (rawRates is Map) {
      for (final e in rawRates.entries) {
        rates[e.key.toString()] = (e.value as num).toDouble();
      }
    }
    return TenantConfig(
      maxTransactionLimit: (json['max_transaction_limit'] as num).toDouble(),
      transferFeeType: json['transfer_fee_type'] as String? ?? 'percentage',
      transferFeeValue: (json['transfer_fee_value'] as num?)?.toDouble() ?? 0,
      baseCurrency: json['base_currency'] as String? ?? 'COP',
      exchangeRates: rates,
      webhookUrl: json['webhook_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'max_transaction_limit': maxTransactionLimit,
        'transfer_fee_type': transferFeeType,
        'transfer_fee_value': transferFeeValue,
        'base_currency': baseCurrency,
        'exchange_rates': exchangeRates,
        'webhook_url': webhookUrl,
      };
}

class TenantInfo {
  const TenantInfo({
    required this.id,
    required this.slug,
    required this.name,
    required this.config,
  });

  final String id;
  final String slug;
  final String name;
  final TenantConfig config;

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      config: TenantConfig.fromJson(
        (json['config'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'config': config.toJson(),
      };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String tenantId;
  final String email;
  final String fullName;
  final String role; // 'administrador' | 'cliente'

  bool get isAdmin => role == 'administrador';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'email': email,
        'full_name': fullName,
        'role': role,
      };
}

class UserSession {
  const UserSession({
    required this.accessToken,
    required this.user,
    required this.tenant,
  });

  final String accessToken;
  final UserProfile user;
  final TenantInfo tenant;

  UserSession copyWith({TenantInfo? tenant}) {
    return UserSession(
      accessToken: accessToken,
      user: user,
      tenant: tenant ?? this.tenant,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      accessToken: json['access_token'] as String,
      user: UserProfile.fromJson((json['user'] as Map).cast<String, dynamic>()),
      tenant: TenantInfo.fromJson(
        (json['tenant'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'user': user.toJson(),
        'tenant': tenant.toJson(),
      };
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.accountNumber,
    required this.ownerUserId,
    required this.ownerName,
    required this.balance,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.deactivatedAt,
  });

  final String id;
  final String accountNumber;
  final String ownerUserId;
  final String ownerName;
  final double balance;
  final String currency;
  final String status; // 'activa' | 'inactiva' | 'bloqueada'
  final DateTime createdAt;
  final DateTime? deactivatedAt;

  bool get isActive => status == 'activa';

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      accountNumber: json['account_number'] as String,
      ownerUserId: json['owner_user_id'] as String,
      ownerName: json['owner_name'] as String? ?? '',
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      deactivatedAt: json['deactivated_at'] != null
          ? DateTime.parse(json['deactivated_at'] as String)
          : null,
    );
  }
}

class DestinationLookup {
  const DestinationLookup({
    required this.accountNumber,
    required this.ownerName,
    required this.currency,
    required this.status,
  });

  final String accountNumber;
  final String ownerName;
  final String currency;
  final String status;

  bool get isActive => status == 'activa';

  factory DestinationLookup.fromJson(Map<String, dynamic> json) {
    return DestinationLookup(
      accountNumber: json['account_number'] as String,
      ownerName: json['owner_name'] as String,
      currency: json['currency'] as String,
      status: json['status'] as String,
    );
  }
}

class TransferQuote {
  const TransferQuote({
    required this.sourceAccountNumber,
    required this.destinationAccountNumber,
    required this.destinationOwnerName,
    required this.originalAmount,
    required this.sourceCurrency,
    required this.feeAmount,
    required this.feeType,
    required this.feeRateValue,
    required this.totalDebitAmount,
    required this.exchangeRate,
    required this.convertedAmount,
    required this.destinationCurrency,
    required this.hasCurrencyConversion,
  });

  final String sourceAccountNumber;
  final String destinationAccountNumber;
  final String destinationOwnerName;
  final double originalAmount;
  final String sourceCurrency;
  final double feeAmount;
  final String feeType;
  final double feeRateValue;
  final double totalDebitAmount;
  final double exchangeRate;
  final double convertedAmount;
  final String destinationCurrency;
  final bool hasCurrencyConversion;

  factory TransferQuote.fromJson(Map<String, dynamic> json) {
    return TransferQuote(
      sourceAccountNumber: json['source_account_number'] as String,
      destinationAccountNumber: json['destination_account_number'] as String,
      destinationOwnerName: json['destination_owner_name'] as String,
      originalAmount: (json['original_amount'] as num).toDouble(),
      sourceCurrency: json['source_currency'] as String,
      feeAmount: (json['fee_amount'] as num).toDouble(),
      feeType: json['fee_type'] as String,
      feeRateValue: (json['fee_rate_value'] as num).toDouble(),
      totalDebitAmount: (json['total_debit_amount'] as num).toDouble(),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      convertedAmount: (json['converted_amount'] as num).toDouble(),
      destinationCurrency: json['destination_currency'] as String,
      hasCurrencyConversion: json['has_currency_conversion'] as bool,
    );
  }
}

enum OperationKind { deposit, withdrawal, transfer }

/// Immutable draft created right before executing a financial operation.
/// Preserves the exact [idempotencyKey] and [correlationId] across all
/// automatic or manual network retries to guarantee zero double-charging.
class OperationDraft {
  OperationDraft({
    required this.kind,
    required this.sourceAccountNumber,
    required this.sourceCurrency,
    required this.originalAmount,
    required this.feeAmount,
    required this.totalDebitAmount,
    required this.convertedAmount,
    required this.destinationCurrency,
    required this.exchangeRate,
    this.destinationAccountNumber,
    this.destinationOwnerName,
    this.description,
    String? idempotencyKey,
    String? correlationId,
  })  : idempotencyKey = idempotencyKey ?? const Uuid().v4(),
        correlationId = correlationId ?? const Uuid().v4();

  final OperationKind kind;
  final String sourceAccountNumber;
  final String sourceCurrency;
  final String? destinationAccountNumber;
  final String? destinationOwnerName;
  final double originalAmount;
  final double feeAmount;
  final double totalDebitAmount;
  final double convertedAmount;
  final String destinationCurrency;
  final double exchangeRate;
  final String? description;
  final String idempotencyKey;
  final String correlationId;

  bool get hasCurrencyConversion => sourceCurrency != destinationCurrency;
  bool get requiresLocal2FA =>
      kind == OperationKind.transfer || kind == OperationKind.withdrawal;
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    this.sourceAccountNumber,
    this.destinationAccountNumber,
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedAmount,
    required this.destinationCurrency,
    required this.exchangeRate,
    required this.feeAmount,
    required this.feeCurrency,
    required this.totalDebited,
    required this.status,
    required this.idempotencyKey,
    required this.correlationId,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String type; // 'deposit' | 'withdrawal' | 'transfer'
  final String? sourceAccountNumber;
  final String? destinationAccountNumber;
  final double originalAmount;
  final String originalCurrency;
  final double convertedAmount;
  final String destinationCurrency;
  final double exchangeRate;
  final double feeAmount;
  final String feeCurrency;
  final double totalDebited;
  final String status; // 'SUCCESS' | 'FAILED'
  final String idempotencyKey;
  final String correlationId;
  final String? description;
  final DateTime createdAt;

  bool get hasFee => feeAmount > 0;
  bool get hasCurrencyConversion => originalCurrency != destinationCurrency;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      type: json['type'] as String,
      sourceAccountNumber: json['source_account_number'] as String?,
      destinationAccountNumber: json['destination_account_number'] as String?,
      originalAmount: (json['original_amount'] as num).toDouble(),
      originalCurrency: json['original_currency'] as String,
      convertedAmount: (json['converted_amount'] as num).toDouble(),
      destinationCurrency: json['destination_currency'] as String,
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      feeAmount: (json['fee_amount'] as num).toDouble(),
      feeCurrency: json['fee_currency'] as String,
      totalDebited: (json['total_debited'] as num).toDouble(),
      status: json['status'] as String,
      idempotencyKey: json['idempotency_key'] as String,
      correlationId: json['correlation_id'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ExecutionReceipt {
  const ExecutionReceipt({
    required this.transaction,
    required this.wasReplayed,
    required this.attemptsUsed,
    required this.correlationId,
  });

  final TransactionItem transaction;
  final bool wasReplayed;
  final int attemptsUsed;
  final String correlationId;
}

class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
      hasNext: json['has_next'] as bool? ?? false,
    );
  }
}

class PaginatedTransactions {
  const PaginatedTransactions({
    required this.items,
    required this.pagination,
  });

  final List<TransactionItem> items;
  final PaginationMeta pagination;
}

class AuditLogItem {
  const AuditLogItem({
    required this.id,
    required this.actorEmail,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.correlationId,
    required this.createdAt,
    this.previousState,
    this.newState,
  });

  final String id;
  final String actorEmail;
  final String action;
  final String entityType;
  final String entityId;
  final String correlationId;
  final DateTime createdAt;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id'] as String,
      actorEmail: json['actor_email'] as String,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      correlationId: json['correlation_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      previousState: json['previous_state'] is Map
          ? (json['previous_state'] as Map).cast<String, dynamic>()
          : null,
      newState: json['new_state'] is Map
          ? (json['new_state'] as Map).cast<String, dynamic>()
          : null,
    );
  }
}
