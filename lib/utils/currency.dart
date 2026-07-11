String formatCurrency(num amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();

  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(intPart[i]);
  }

  return 'Rs ${buffer.toString()}.$decPart';
}

String formatCurrencyFromString(String amount) {
  return formatCurrency(double.tryParse(amount) ?? 0);
}
