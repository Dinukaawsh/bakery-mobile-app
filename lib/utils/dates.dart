/// Sri Lanka business dates (Asia/Colombo, UTC+05:30, no DST).
const Duration colomboOffset = Duration(hours: 5, minutes: 30);

DateTime toColombo(DateTime date) {
  return date.toUtc().add(colomboOffset);
}

/// Today's calendar date (YYYY-MM-DD) in Sri Lanka.
String localDateString([DateTime? date]) {
  final colombo = toColombo(date ?? DateTime.now());
  final month = colombo.month.toString().padLeft(2, '0');
  final day = colombo.day.toString().padLeft(2, '0');
  return '${colombo.year}-$month-$day';
}
