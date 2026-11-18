import 'package:intl/intl.dart';

class BankFormatters {
  static String money(double amount, String currency) {
    final upper = currency.toUpperCase();
    final decimals = upper == 'COP' ? 0 : 2;
    final symbol = switch (upper) {
      'USD' => r'$',
      'EUR' => '€',
      'COP' => r'$',
      _ => '$upper ',
    };
    final fmt = NumberFormat.currency(
      locale: 'en_US',
      symbol: symbol,
      decimalDigits: decimals,
    );
    return '${fmt.format(amount)} $upper';
  }

  static String rate(double rate) {
    if (rate >= 10) return rate.toStringAsFixed(2);
    if (rate >= 1) return rate.toStringAsFixed(4);
    return rate.toStringAsFixed(6);
  }

  static String dateTime(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(local);
  }

  static String shortUuid(String uuid) {
    if (uuid.length <= 14) return uuid;
    return '${uuid.substring(0, 8)}...${uuid.substring(uuid.length - 4)}';
  }
}
