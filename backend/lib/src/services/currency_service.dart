import '../models/api_response.dart';
import '../models/domain_models.dart';

class CurrencyConversion {
  const CurrencyConversion({
    required this.rate,
    required this.convertedAmount,
  });

  final double rate;
  final double convertedAmount;
}

class CurrencyService {
  const CurrencyService();

  double calculateTransferFee(TenantConfig config, double amount) {
    final rawFee = switch (config.transferFeeType) {
      FeeType.fixed => config.transferFeeValue,
      FeeType.percentage => amount * (config.transferFeeValue / 100.0),
    };
    return round2(rawFee);
  }

  /// Resolves static FX rate from [fromCurrency] to [toCurrency] using the
  /// tenant's exchange_rates map (direct pair -> inverse pair -> via baseCurrency).
  double resolveExchangeRate(
    TenantConfig config,
    String fromCurrency,
    String toCurrency,
  ) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) return 1.0;

    final rates = config.exchangeRates;
    final directKey = '${from}_$to';
    if (rates.containsKey(directKey) && rates[directKey]! > 0) {
      return rates[directKey]!;
    }

    final inverseKey = '${to}_$from';
    if (rates.containsKey(inverseKey) && rates[inverseKey]! > 0) {
      return 1.0 / rates[inverseKey]!;
    }

    // Attempt bridge conversion through tenant baseCurrency
    final base = config.baseCurrency.toUpperCase();
    if (from != base && to != base) {
      final toBase = _directOrInverse(rates, from, base);
      final fromBase = _directOrInverse(rates, base, to);
      if (toBase != null && fromBase != null) {
        return toBase * fromBase;
      }
    }

    throw AppException(
      statusCode: 422,
      code: 'EXCHANGE_RATE_NOT_CONFIGURED',
      message:
          'No existe tasa de cambio configurada para convertir $from a $to en este tenant',
    );
  }

  CurrencyConversion convert(
    TenantConfig config, {
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    final rate = resolveExchangeRate(config, fromCurrency, toCurrency);
    final converted = round2(amount * rate);
    return CurrencyConversion(rate: rate, convertedAmount: converted);
  }

  /// Validates [amount] in [currency] against tenant's [maxTransactionLimit]
  /// expressed in [config.baseCurrency].
  void validateMaxLimit(
    TenantConfig config, {
    required double amount,
    required String currency,
  }) {
    final normalized = currency.toUpperCase();
    final base = config.baseCurrency.toUpperCase();
    final equivalentInBase = normalized == base
        ? amount
        : convert(
            config,
            amount: amount,
            fromCurrency: normalized,
            toCurrency: base,
          ).convertedAmount;

    if (equivalentInBase > config.maxTransactionLimit) {
      throw AppException(
        statusCode: 422,
        code: 'TRANSACTION_LIMIT_EXCEEDED',
        message:
            'El monto excede el límite máximo por transacción (${config.maxTransactionLimit.toStringAsFixed(2)} $base)',
        details: {
          'max_transaction_limit': config.maxTransactionLimit,
          'base_currency': base,
          'attempted_equivalent_in_base': equivalentInBase,
        },
      );
    }
  }

  double? _directOrInverse(
    Map<String, double> rates,
    String from,
    String to,
  ) {
    final direct = rates['${from}_$to'];
    if (direct != null && direct > 0) return direct;
    final inverse = rates['${to}_$from'];
    if (inverse != null && inverse > 0) return 1.0 / inverse;
    return null;
  }

  double round2(double value) => (value * 100).roundToDouble() / 100;
}
