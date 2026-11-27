int? parseMoneyInKurus(String input) {
  final text = input.trim();
  if (!RegExp(r'^[0-9]+([,.][0-9]{1,2})?$').hasMatch(text)) return null;

  final parts = text.replaceAll(',', '.').split('.');
  final kurus = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return int.tryParse('${parts[0]}$kurus');
}

String formatAmount(int kurus) {
  final absolute = kurus.abs();
  final lira = absolute ~/ 100;
  final remaining = (absolute % 100).toString().padLeft(2, '0');
  final sign = kurus < 0 ? '-' : '';
  return '$sign$lira,$remaining';
}

String formatMoney(int kurus) => '${formatAmount(kurus)} TL';
