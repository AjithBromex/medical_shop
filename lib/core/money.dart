/// All money is stored as integer paise (1 rupee = 100 paise). No floating point maths.
const int maxRupees = 10 * 100 * 100 * 1000; // 10 crore sanity limit per amount
const int maxPaise = maxRupees * 100;

/// Parses user input such as "1,250.50" into paise. Throws [FormatException] with a
/// user-friendly message.
int parseAmount(String? raw, String label, {bool allowZero = true}) {
  final text = (raw ?? '').trim().replaceAll(',', '').replaceAll('₹', '').replaceAll(' ', '');
  if (text.isEmpty) {
    if (allowZero) return 0;
    throw FormatException('$label is required.');
  }
  if (text.startsWith('-')) throw FormatException('$label cannot be negative.');
  final match = RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(text);
  if (match == null) throw FormatException('$label must be a valid number.');
  final whole = match.group(1)!;
  final frac = match.group(2) ?? '';
  if (frac.length > 2 && frac.substring(2).replaceAll('0', '').isNotEmpty) {
    throw FormatException('$label can have at most 2 decimal places.');
  }
  final paiseFrac = int.parse((frac.padRight(2, '0')).substring(0, 2));
  if (whole.length > 12) throw FormatException('$label is too large.');
  final paise = int.parse(whole) * 100 + paiseFrac;
  if (paise > maxPaise) throw FormatException('$label is too large.');
  if (paise == 0 && !allowZero) throw FormatException('$label must be greater than zero.');
  return paise;
}

/// ₹12,34,567 with Indian digit grouping (no decimals for whole rupees).
String inr(int? paise) {
  final p = paise ?? 0;
  final sign = p < 0 ? '-' : '';
  final abs = p.abs();
  final rupees = abs ~/ 100;
  final rem = abs % 100;
  var digits = rupees.toString();
  if (digits.length > 3) {
    var head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    digits = [...groups, tail].join(',');
  }
  if (rem == 0) {
    return '$sign₹$digits';
  }
  final ps = rem.toString().padLeft(2, '0');
  return '$sign₹$digits.$ps';
}

/// Plain rupees for inputs / CSV, e.g. 1500 (or 1250.50 if paise != 0)
String plain(int? paise) {
  final p = paise ?? 0;
  final abs = p.abs();
  final rem = abs % 100;
  if (rem == 0) return '${p < 0 ? '-' : ''}${abs ~/ 100}';
  return '${p < 0 ? '-' : ''}${abs ~/ 100}.${rem.toString().padLeft(2, '0')}';
}

/// Float rupees - charts only, never calculations.
double rupees(int? paise) => (paise ?? 0) / 100;
