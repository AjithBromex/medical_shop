import 'package:intl/intl.dart';

final _dmy = DateFormat('dd-MM-yyyy');
final _iso = DateFormat('yyyy-MM-dd');

String dmy(DateTime? d) => d == null ? '' : _dmy.format(d);
String isoDate(DateTime d) => _iso.format(d);
DateTime parseIso(String s) {
  final clean = s.trim();
  final p = DateTime.tryParse(clean) ?? DateTime.now();
  return DateTime(p.year, p.month, p.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());
String shortDay(DateTime d) => DateFormat('dd MMM').format(d);
String dayWithDmy(DateTime d) => DateFormat('EEE, dd-MM-yyyy').format(d);
String monthLabel(String ym) {
  final clean = ym.trim();
  final parsed = DateTime.tryParse('$clean-01') ?? DateTime.now();
  return DateFormat('MMM yyyy').format(parsed);
}
