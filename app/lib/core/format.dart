import 'package:intl/intl.dart';

final _money = NumberFormat.decimalPattern('en_PK');
final _dateTime = DateFormat('d MMM, h:mm a');
final _date = DateFormat('d MMM yyyy');

String rs(String? amount) {
  final v = double.tryParse(amount ?? '');
  if (v == null) return 'Rs —';
  return 'Rs ${_money.format(v.round())}';
}

String when(DateTime? d) => d == null ? '' : _dateTime.format(d);
String day(DateTime? d) => d == null ? '' : _date.format(d);

String ago(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return day(d);
}

String humanize(String code) {
  final s = code.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

const bookingStatusLabels = {
  'confirmed': 'Confirmed',
  'on_the_way': 'On the way',
  'arrived': 'Arrived',
  'in_progress': 'Work in progress',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};

String bookingStatusLabel(String s) => bookingStatusLabels[s] ?? humanize(s);
