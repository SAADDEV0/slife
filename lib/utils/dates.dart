import 'package:intl/intl.dart';

class Dates {
  Dates._();

  static final _key = DateFormat('yyyy-MM-dd');
  static final _dayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// `yyyy-MM-dd` key for a local date.
  static String key(DateTime date) => _key.format(date);

  static String todayKey() => key(DateTime.now());

  static bool isDayKey(String value) => _dayKeyPattern.hasMatch(value);

  /// Parses a day key into local midnight.
  static DateTime parse(String dayKey) {
    final parts = dayKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime previousDay(DateTime d) =>
      DateTime(d.year, d.month, d.day - 1);

  static bool isToday(String dayKey) => dayKey == todayKey();

  static bool isFuture(DateTime day) => day.isAfter(today());

  /// 12 October 2026
  static String long(DateTime d) => DateFormat('d MMMM y').format(d);

  /// Monday
  static String weekday(DateTime d) => DateFormat('EEEE').format(d);

  /// Mon
  static String shortWeekday(DateTime d) => DateFormat('EEE').format(d);

  /// Monday, 12 Oct
  static String header(DateTime d) => DateFormat('EEEE, d MMM').format(d);

  /// Mon, 12 Oct 2026
  static String compact(DateTime d) => DateFormat('EEE, d MMM y').format(d);

  /// October 2026
  static String month(DateTime d) => DateFormat('MMMM y').format(d);

  /// 10:15
  static String time(DateTime d) => DateFormat('HH:mm').format(d);

  static String greeting([DateTime? at]) {
    final h = (at ?? DateTime.now()).hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return compact(t);
  }

  /// 1:05 or 1:02:09
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }
}
