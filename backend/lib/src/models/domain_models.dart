enum FeeType {
  fixed('fixed'),
  percentage('percentage');

  const FeeType(this.value);
  final String value;

  static FeeType fromString(String raw) {
    return FeeType.values.firstWhere(
      (e) => e.value == raw.toLowerCase(),
      orElse: () => throw FormatException('Invalid fee type: $raw'),
    );
  }
}

enum UserRole {
  administrador('administrador'),
  cliente('cliente');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String raw) {
    return UserRole.values.firstWhere(
      (e) => e.value == raw.toLowerCase(),
      orElse: () => throw FormatException('Invalid user role: $raw'),
    );
  }
}

enum AccountStatus {
  activa('activa'),
  inactiva('inactiva'),
  bloqueada('bloqueada');

  const AccountStatus(this.value);
  final String value;

  bool get isOperational => this == AccountStatus.activa;

  static AccountStatus fromString(String raw) {
    return AccountStatus.values.firstWhere(
      (e) => e.value == raw.toLowerCase(),
      orElse: () => throw FormatException('Invalid account status: $raw'),
    );
  }
}

enum TransactionType {
  deposit('deposit'),
  withdrawal('withdrawal'),
  transfer('transfer');

  const TransactionType(this.value);
  final String value;

  static TransactionType fromString(String raw) {
    return TransactionType.values.firstWhere(
      (e) => e.value == raw.toLowerCase(),
      orElse: () => throw FormatException('Invalid transaction type: $raw'),
    );
  }
}

enum TransactionStatus {
  success('SUCCESS'),
  failed('FAILED');

  const TransactionStatus(this.value);
  final String value;

  static TransactionStatus fromString(String raw) {
    return TransactionStatus.values.firstWhere(
      (e) => e.value == raw.toUpperCase(),
      orElse: () => throw FormatException('Invalid transaction status: $raw'),
    );
  }
}

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
  final FeeType transferFeeType;
  final double transferFeeValue;
  final String baseCurrency;
  final Map<String, double> exchangeRates;
  final String? webhookUrl;

  TenantConfig copyWith({
    double? maxTransactionLimit,
    FeeType? transferFeeType,
    double? transferFeeValue,
    String? baseCurrency,
    Map<String, double>? exchangeRates,
    String? webhookUrl,
    bool clearWebhookUrl = false,
  }) {
    return TenantConfig(
      maxTransactionLimit: maxTransactionLimit ?? this.maxTransactionLimit,
      transferFeeType: transferFeeType ?? this.transferFeeType,
      transferFeeValue: transferFeeValue ?? this.transferFeeValue,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      exchangeRates: exchangeRates ?? this.exchangeRates,
      webhookUrl: clearWebhookUrl ? null : (webhookUrl ?? this.webhookUrl),
    );
  }

  Map<String, Object?> toJson() => {
        'max_transaction_limit': maxTransactionLimit,
        'transfer_fee_type': transferFeeType.value,
        'transfer_fee_value': transferFeeValue,
        'base_currency': baseCurrency,
        'exchange_rates': exchangeRates,
        'webhook_url': webhookUrl,
      };

  static TenantConfig fromJson(Map<String, Object?> json) {
    final rawRates = json['exchange_rates'];
    final rates = <String, double>{};
    if (rawRates is Map) {
      for (final entry in rawRates.entries) {
        final key = entry.key.toString().toUpperCase();
        final val = (entry.value as num).toDouble();
        rates[key] = val;
      }
    }
    return TenantConfig(
      maxTransactionLimit: (json['max_transaction_limit'] as num).toDouble(),
      transferFeeType: FeeType.fromString(json['transfer_fee_type'] as String),
      transferFeeValue: (json['transfer_fee_value'] as num).toDouble(),
      baseCurrency: (json['base_currency'] as String).toUpperCase(),
      exchangeRates: rates,
      webhookUrl: json['webhook_url'] as String?,
    );
  }
}

class Tenant {
  const Tenant({
    required this.id,
    required this.slug,
    required this.name,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String slug;
  final String name;
  final TenantConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tenant copyWith({
    String? name,
    TenantConfig? config,
    DateTime? updatedAt,
  }) {
    return Tenant(
      id: id,
      slug: slug,
      name: name ?? this.name,
      config: config ?? this.config,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'config': config.toJson(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

class User {
  const User({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.fullName,
    required this.passwordHash,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String email;
  final String fullName;
  final String passwordHash;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  Map<String, Object?> toSafeJson() => {
        'id': id,
        'tenant_id': tenantId,
        'email': email,
        'full_name': fullName,
        'role': role.value,
        'is_active': isActive,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.tenantId,
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
  final String tenantId;
  final String accountNumber;
  final String ownerUserId;
  final String ownerName;
  final double balance;
  final String currency;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime? deactivatedAt;

  BankAccount copyWith({
    double? balance,
    AccountStatus? status,
    DateTime? deactivatedAt,
    bool clearDeactivatedAt = false,
  }) {
    return BankAccount(
      id: id,
      tenantId: tenantId,
      accountNumber: accountNumber,
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      balance: balance ?? this.balance,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
      deactivatedAt:
          clearDeactivatedAt ? null : (deactivatedAt ?? this.deactivatedAt),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'account_number': accountNumber,
        'owner_user_id': ownerUserId,
        'owner_name': ownerName,
        'balance': balance,
        'currency': currency,
        'status': status.value,
        'created_at': createdAt.toUtc().toIso8601String(),
        'deactivated_at': deactivatedAt?.toUtc().toIso8601String(),
      };

  Map<String, Object?> toLookupJson() => {
        'account_number': accountNumber,
        'owner_name': ownerName,
        'currency': currency,
        'status': status.value,
      };
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.tenantId,
    required this.initiatedByUserId,
    required this.type,
    this.sourceAccountId,
    this.sourceAccountNumber,
    this.destinationAccountId,
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
    this.failureReason,
    required this.idempotencyKey,
    required this.correlationId,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String initiatedByUserId;
  final TransactionType type;
  final String? sourceAccountId;
  final String? sourceAccountNumber;
  final String? destinationAccountId;
  final String? destinationAccountNumber;
  final double originalAmount;
  final String originalCurrency;
  final double convertedAmount;
  final String destinationCurrency;
  final double exchangeRate;
  final double feeAmount;
  final String feeCurrency;
  final double totalDebited;
  final TransactionStatus status;
  final String? failureReason;
  final String idempotencyKey;
  final String correlationId;
  final String? description;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'initiated_by_user_id': initiatedByUserId,
        'type': type.value,
        'source_account_id': sourceAccountId,
        'source_account_number': sourceAccountNumber,
        'destination_account_id': destinationAccountId,
        'destination_account_number': destinationAccountNumber,
        'original_amount': originalAmount,
        'original_currency': originalCurrency,
        'converted_amount': convertedAmount,
        'destination_currency': destinationCurrency,
        'exchange_rate': exchangeRate,
        'fee_amount': feeAmount,
        'fee_currency': feeCurrency,
        'total_debited': totalDebited,
        'status': status.value,
        'failure_reason': failureReason,
        'idempotency_key': idempotencyKey,
        'correlation_id': correlationId,
        'description': description,
        'has_fee': feeAmount > 0,
        'has_currency_conversion': originalCurrency != destinationCurrency,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.tenantId,
    required this.actorUserId,
    required this.actorEmail,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.previousState,
    this.newState,
    required this.correlationId,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String actorUserId;
  final String actorEmail;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, Object?>? previousState;
  final Map<String, Object?>? newState;
  final String correlationId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'actor_user_id': actorUserId,
        'actor_email': actorEmail,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'previous_state': previousState,
        'new_state': newState,
        'correlation_id': correlationId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
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
  final FeeType feeType;
  final double feeRateValue;
  final double totalDebitAmount;
  final double exchangeRate;
  final double convertedAmount;
  final String destinationCurrency;
  final bool hasCurrencyConversion;

  Map<String, Object?> toJson() => {
        'source_account_number': sourceAccountNumber,
        'destination_account_number': destinationAccountNumber,
        'destination_owner_name': destinationOwnerName,
        'original_amount': originalAmount,
        'source_currency': sourceCurrency,
        'fee_amount': feeAmount,
        'fee_type': feeType.value,
        'fee_rate_value': feeRateValue,
        'total_debit_amount': totalDebitAmount,
        'exchange_rate': exchangeRate,
        'converted_amount': convertedAmount,
        'destination_currency': destinationCurrency,
        'has_currency_conversion': hasCurrencyConversion,
      };
}

class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;

  int get totalPages => total == 0 ? 1 : (total / limit).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  Map<String, Object?> paginationMeta() => {
        'page': page,
        'limit': limit,
        'total': total,
        'total_pages': totalPages,
        'has_next': hasNext,
        'has_previous': hasPrevious,
      };
}

class AuthContext {
  const AuthContext({
    required this.tenantId,
    required this.tenantSlug,
    required this.userId,
    required this.email,
    required this.role,
  });

  final String tenantId;
  final String tenantSlug;
  final String userId;
  final String email;
  final UserRole role;
}
