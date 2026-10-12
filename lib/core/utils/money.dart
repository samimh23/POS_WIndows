/// TND amounts are integer millimes throughout the application.
String money(int value) => '${moneyInput(value)} DT';

String moneyInput(int value) =>
    '${value < 0 ? '-' : ''}${value.abs() ~/ 1000}.${(value.abs() % 1000).toString().padLeft(3, '0')}';

int parseMoney(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,8}(\.\d{1,3})?$').hasMatch(text)) {
    throw const FormatException(
      'Enter a positive amount with up to 3 decimals.',
    );
  }
  final parts = text.split('.');
  return int.parse(parts.first) * 1000 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(3, '0')));
}

String stamp(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
