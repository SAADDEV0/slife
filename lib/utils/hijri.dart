/// Islamic (Hijri) date from the tabular calendar.
///
/// The tabular calendar is arithmetic, so it can differ by a day from the
/// moon-sighting or Umm al-Qura date used locally. The UI labels it as
/// approximate.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const months = [
    'Muharram',
    'Safar',
    'Rabiʿ al-Awwal',
    'Rabiʿ al-Thani',
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    'Shaʿban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qaʿdah',
    'Dhu al-Hijjah',
  ];

  static const monthsArabic = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  String get monthName => months[month - 1];
  String get monthArabic => monthsArabic[month - 1];

  /// 10 Jumada al-Ula 1448
  @override
  String toString() => '$day $monthName $year';

  factory HijriDate.fromGregorian(DateTime date) {
    // Julian day number (at noon) of the civil date.
    final a = (14 - date.month) ~/ 12;
    final y = date.year + 4800 - a;
    final m = date.month + 12 * a - 3;
    final jd =
        date.day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;

    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j =
        ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l =
        l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }
}
