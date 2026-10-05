import 'package:intl/intl.dart';

/// A supported currency. Amounts are never converted between currencies.
class Currency {
  const Currency(this.code, this.symbol, this.name, {this.decimals = 2});

  final String code;
  final String symbol;
  final String name;
  final int decimals;
}

const List<Currency> kCurrencies = [
  Currency('LKR', 'Rs', 'Sri Lankan Rupee'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('JPY', '¥', 'Japanese Yen', decimals: 0),
];

const String kDefaultCurrency = 'LKR';

Currency currencyOf(String code) => kCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => kCurrencies.first,
    );

/// Minus sign used for display (U+2212), not a hyphen.
const String kMinus = '−';

final Map<int, NumberFormat> _formats = {};

NumberFormat _format(int decimals) => _formats.putIfAbsent(
      decimals,
      // Fixed en_US grouping regardless of app language — intentional.
      () => NumberFormat(
        decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}',
        'en_US',
      ),
    );

/// `Rs 1,250.00`. Number formatting is fixed whatever the UI language.
String formatMoney(double amount, String currencyCode, {bool showSymbol = true, bool whole = false}) {
  final cur = currencyOf(currencyCode);
  final digits = _format(whole ? 0 : cur.decimals).format(amount.abs());
  final sign = amount < 0 ? '$kMinus ' : '';
  return showSymbol ? '$sign${cur.symbol} $digits' : '$sign$digits';
}

/// `+ Rs 80,000.00` / `− Rs 1,250.00`. Zero gets no sign.
String formatSigned(double amount, String currencyCode, {bool showSymbol = true, bool whole = false}) {
  if (amount == 0) return formatMoney(0, currencyCode, showSymbol: showSymbol, whole: whole);
  final body = formatMoney(amount.abs(), currencyCode, showSymbol: showSymbol, whole: whole);
  return amount > 0 ? '+ $body' : '$kMinus $body';
}
