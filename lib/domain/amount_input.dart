// Keypad input rules for the Add sheet. The amount is kept as the raw typed
// string (so "12." and "12.50" display exactly as typed) and parsed on save.

const String kKeyBackspace = 'back';
const String kKeyDecimal = '.';

String applyAmountKey(
  String current,
  String key, {
  int decimals = 2,
  int maxDigits = 10,
}) {
  if (key == kKeyBackspace) {
    return current.isEmpty ? current : current.substring(0, current.length - 1);
  }
  if (key == kKeyDecimal) {
    if (decimals == 0 || current.contains('.')) return current;
    return current.isEmpty ? '0.' : '$current.';
  }
  if (key.length != 1 || key.codeUnitAt(0) < 48 || key.codeUnitAt(0) > 57) {
    return current;
  }
  if (current.contains('.') && current.split('.')[1].length >= decimals) {
    return current;
  }
  if (current.replaceAll('.', '').length >= maxDigits) return current;
  if (current == '0') return key;
  return current + key;
}

double parseAmount(String s) => double.tryParse(s) ?? 0;

/// Groups the integer part with commas and keeps the typed decimal part.
String displayAmount(String s) {
  if (s.isEmpty) return '0';
  final parts = s.split('.');
  final intPart = parts[0].isEmpty ? '0' : parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}

/// Turns a stored amount back into keypad text (for editing).
String amountToInput(double v, {int decimals = 2}) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(decimals);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
