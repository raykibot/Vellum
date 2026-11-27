import 'package:intl/intl.dart';

const List<String> _weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

String formatMonthKey(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}年${local.month}月';
}

String formatWeekday(DateTime dt) {
  final local = dt.toLocal();
  return _weekdays[local.weekday % 7];
}

String formatDay(DateTime dt) {
  final local = dt.toLocal();
  return local.day.toString();
}

String formatTime(DateTime dt) {
  return DateFormat('HH:mm').format(dt.toLocal());
}

String formatDetailMeta(DateTime dt, String? city) {
  final local = dt.toLocal();
  final datePart =
      '${local.year}年${local.month}月${local.day}日 ${formatWeekday(local)} · ${formatTime(local)}';
  if (city != null && city.trim().isNotEmpty) {
    return '$datePart · ${city.trim()}';
  }
  return datePart;
}

String formatTimelineMeta(DateTime dt, String? city) {
  final timePart = formatTime(dt);
  if (city != null && city.trim().isNotEmpty) {
    return '$timePart · ${city.trim()}';
  }
  return timePart;
}

String formatDotDate(DateTime dt) {
  return DateFormat('yyyy.MM.dd').format(dt.toLocal());
}

String formatApiDate(DateTime dt) {
  return DateFormat('yyyy-MM-dd').format(dt.toLocal());
}
