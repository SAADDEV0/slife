import 'package:flutter/foundation.dart';

/// One of the 114 surahs of the Quran.
@immutable
class Surah {
  const Surah(
    this.number,
    this.arabic,
    this.name,
    this.meaning,
    this.ayahs,
    this.meccan,
  );

  final int number;
  final String arabic;

  /// Transliterated name, e.g. "Al-Fatihah".
  final String name;

  /// English meaning of the name.
  final String meaning;
  final int ayahs;
  final bool meccan;

  String get revelation => meccan ? 'Meccan' : 'Medinan';

  /// Every surah except At-Tawbah opens with the Basmala; in Al-Fatihah it
  /// is the first ayah itself.
  bool get hasBasmalaHeader => number != 1 && number != 9;

  static Surah byNumber(int number) => all[number - 1];

  static const all = <Surah>[
    Surah(1, 'الفاتحة', 'Al-Fatihah', 'The Opening', 7, true),
    Surah(2, 'البقرة', 'Al-Baqarah', 'The Cow', 286, false),
    Surah(3, 'آل عمران', 'Ali ʿImran', 'Family of Imran', 200, false),
    Surah(4, 'النساء', 'An-Nisa', 'The Women', 176, false),
    Surah(5, 'المائدة', 'Al-Maʾidah', 'The Table Spread', 120, false),
    Surah(6, 'الأنعام', 'Al-Anʿam', 'The Cattle', 165, true),
    Surah(7, 'الأعراف', 'Al-Aʿraf', 'The Heights', 206, true),
    Surah(8, 'الأنفال', 'Al-Anfal', 'The Spoils of War', 75, false),
    Surah(9, 'التوبة', 'At-Tawbah', 'The Repentance', 129, false),
    Surah(10, 'يونس', 'Yunus', 'Jonah', 109, true),
    Surah(11, 'هود', 'Hud', 'Hud', 123, true),
    Surah(12, 'يوسف', 'Yusuf', 'Joseph', 111, true),
    Surah(13, 'الرعد', 'Ar-Raʿd', 'The Thunder', 43, false),
    Surah(14, 'إبراهيم', 'Ibrahim', 'Abraham', 52, true),
    Surah(15, 'الحجر', 'Al-Hijr', 'The Rocky Tract', 99, true),
    Surah(16, 'النحل', 'An-Nahl', 'The Bee', 128, true),
    Surah(17, 'الإسراء', 'Al-Isra', 'The Night Journey', 111, true),
    Surah(18, 'الكهف', 'Al-Kahf', 'The Cave', 110, true),
    Surah(19, 'مريم', 'Maryam', 'Mary', 98, true),
    Surah(20, 'طه', 'Ta-Ha', 'Ta-Ha', 135, true),
    Surah(21, 'الأنبياء', 'Al-Anbiya', 'The Prophets', 112, true),
    Surah(22, 'الحج', 'Al-Hajj', 'The Pilgrimage', 78, false),
    Surah(23, 'المؤمنون', 'Al-Muʾminun', 'The Believers', 118, true),
    Surah(24, 'النور', 'An-Nur', 'The Light', 64, false),
    Surah(25, 'الفرقان', 'Al-Furqan', 'The Criterion', 77, true),
    Surah(26, 'الشعراء', 'Ash-Shuʿara', 'The Poets', 227, true),
    Surah(27, 'النمل', 'An-Naml', 'The Ant', 93, true),
    Surah(28, 'القصص', 'Al-Qasas', 'The Stories', 88, true),
    Surah(29, 'العنكبوت', 'Al-ʿAnkabut', 'The Spider', 69, true),
    Surah(30, 'الروم', 'Ar-Rum', 'The Romans', 60, true),
    Surah(31, 'لقمان', 'Luqman', 'Luqman', 34, true),
    Surah(32, 'السجدة', 'As-Sajdah', 'The Prostration', 30, true),
    Surah(33, 'الأحزاب', 'Al-Ahzab', 'The Combined Forces', 73, false),
    Surah(34, 'سبأ', 'Saba', 'Sheba', 54, true),
    Surah(35, 'فاطر', 'Fatir', 'The Originator', 45, true),
    Surah(36, 'يس', 'Ya-Sin', 'Ya-Sin', 83, true),
    Surah(37, 'الصافات', 'As-Saffat', 'Those Who Set the Ranks', 182, true),
    Surah(38, 'ص', 'Sad', 'The Letter Sad', 88, true),
    Surah(39, 'الزمر', 'Az-Zumar', 'The Troops', 75, true),
    Surah(40, 'غافر', 'Ghafir', 'The Forgiver', 85, true),
    Surah(41, 'فصلت', 'Fussilat', 'Explained in Detail', 54, true),
    Surah(42, 'الشورى', 'Ash-Shura', 'The Consultation', 53, true),
    Surah(43, 'الزخرف', 'Az-Zukhruf', 'The Ornaments of Gold', 89, true),
    Surah(44, 'الدخان', 'Ad-Dukhan', 'The Smoke', 59, true),
    Surah(45, 'الجاثية', 'Al-Jathiyah', 'The Crouching', 37, true),
    Surah(46, 'الأحقاف', 'Al-Ahqaf', 'The Wind-Curved Sandhills', 35, true),
    Surah(47, 'محمد', 'Muhammad', 'Muhammad', 38, false),
    Surah(48, 'الفتح', 'Al-Fath', 'The Victory', 29, false),
    Surah(49, 'الحجرات', 'Al-Hujurat', 'The Rooms', 18, false),
    Surah(50, 'ق', 'Qaf', 'The Letter Qaf', 45, true),
    Surah(51, 'الذاريات', 'Adh-Dhariyat', 'The Winnowing Winds', 60, true),
    Surah(52, 'الطور', 'At-Tur', 'The Mount', 49, true),
    Surah(53, 'النجم', 'An-Najm', 'The Star', 62, true),
    Surah(54, 'القمر', 'Al-Qamar', 'The Moon', 55, true),
    Surah(55, 'الرحمن', 'Ar-Rahman', 'The Most Merciful', 78, false),
    Surah(56, 'الواقعة', 'Al-Waqiʿah', 'The Inevitable', 96, true),
    Surah(57, 'الحديد', 'Al-Hadid', 'The Iron', 29, false),
    Surah(58, 'المجادلة', 'Al-Mujadilah', 'The Pleading Woman', 22, false),
    Surah(59, 'الحشر', 'Al-Hashr', 'The Exile', 24, false),
    Surah(60, 'الممتحنة', 'Al-Mumtahanah', 'The Examined One', 13, false),
    Surah(61, 'الصف', 'As-Saff', 'The Ranks', 14, false),
    Surah(62, 'الجمعة', 'Al-Jumuʿah', 'Friday', 11, false),
    Surah(63, 'المنافقون', 'Al-Munafiqun', 'The Hypocrites', 11, false),
    Surah(64, 'التغابن', 'At-Taghabun', 'The Mutual Disillusion', 18, false),
    Surah(65, 'الطلاق', 'At-Talaq', 'The Divorce', 12, false),
    Surah(66, 'التحريم', 'At-Tahrim', 'The Prohibition', 12, false),
    Surah(67, 'الملك', 'Al-Mulk', 'The Sovereignty', 30, true),
    Surah(68, 'القلم', 'Al-Qalam', 'The Pen', 52, true),
    Surah(69, 'الحاقة', 'Al-Haqqah', 'The Reality', 52, true),
    Surah(70, 'المعارج', 'Al-Maʿarij', 'The Ascending Stairways', 44, true),
    Surah(71, 'نوح', 'Nuh', 'Noah', 28, true),
    Surah(72, 'الجن', 'Al-Jinn', 'The Jinn', 28, true),
    Surah(73, 'المزمل', 'Al-Muzzammil', 'The Enshrouded One', 20, true),
    Surah(74, 'المدثر', 'Al-Muddaththir', 'The Cloaked One', 56, true),
    Surah(75, 'القيامة', 'Al-Qiyamah', 'The Resurrection', 40, true),
    Surah(76, 'الإنسان', 'Al-Insan', 'Man', 31, false),
    Surah(77, 'المرسلات', 'Al-Mursalat', 'The Emissaries', 50, true),
    Surah(78, 'النبأ', 'An-Nabaʾ', 'The Tidings', 40, true),
    Surah(79, 'النازعات', 'An-Naziʿat', 'Those Who Drag Forth', 46, true),
    Surah(80, 'عبس', 'ʿAbasa', 'He Frowned', 42, true),
    Surah(81, 'التكوير', 'At-Takwir', 'The Overthrowing', 29, true),
    Surah(82, 'الانفطار', 'Al-Infitar', 'The Cleaving', 19, true),
    Surah(83, 'المطففين', 'Al-Mutaffifin', 'The Defrauding', 36, true),
    Surah(84, 'الانشقاق', 'Al-Inshiqaq', 'The Sundering', 25, true),
    Surah(85, 'البروج', 'Al-Buruj', 'The Mansions of the Stars', 22, true),
    Surah(86, 'الطارق', 'At-Tariq', 'The Night Comer', 17, true),
    Surah(87, 'الأعلى', 'Al-Aʿla', 'The Most High', 19, true),
    Surah(88, 'الغاشية', 'Al-Ghashiyah', 'The Overwhelming', 26, true),
    Surah(89, 'الفجر', 'Al-Fajr', 'The Dawn', 30, true),
    Surah(90, 'البلد', 'Al-Balad', 'The City', 20, true),
    Surah(91, 'الشمس', 'Ash-Shams', 'The Sun', 15, true),
    Surah(92, 'الليل', 'Al-Layl', 'The Night', 21, true),
    Surah(93, 'الضحى', 'Ad-Duha', 'The Morning Hours', 11, true),
    Surah(94, 'الشرح', 'Ash-Sharh', 'The Relief', 8, true),
    Surah(95, 'التين', 'At-Tin', 'The Fig', 8, true),
    Surah(96, 'العلق', 'Al-ʿAlaq', 'The Clot', 19, true),
    Surah(97, 'القدر', 'Al-Qadr', 'The Power', 5, true),
    Surah(98, 'البينة', 'Al-Bayyinah', 'The Clear Proof', 8, false),
    Surah(99, 'الزلزلة', 'Az-Zalzalah', 'The Earthquake', 8, false),
    Surah(100, 'العاديات', 'Al-ʿAdiyat', 'The Chargers', 11, true),
    Surah(101, 'القارعة', 'Al-Qariʿah', 'The Calamity', 11, true),
    Surah(102, 'التكاثر', 'At-Takathur', 'The Rivalry in Increase', 8, true),
    Surah(103, 'العصر', 'Al-ʿAsr', 'The Declining Day', 3, true),
    Surah(104, 'الهمزة', 'Al-Humazah', 'The Slanderer', 9, true),
    Surah(105, 'الفيل', 'Al-Fil', 'The Elephant', 5, true),
    Surah(106, 'قريش', 'Quraysh', 'Quraysh', 4, true),
    Surah(107, 'الماعون', 'Al-Maʿun', 'Small Kindnesses', 7, true),
    Surah(108, 'الكوثر', 'Al-Kawthar', 'The Abundance', 3, true),
    Surah(109, 'الكافرون', 'Al-Kafirun', 'The Disbelievers', 6, true),
    Surah(110, 'النصر', 'An-Nasr', 'The Divine Support', 3, false),
    Surah(111, 'المسد', 'Al-Masad', 'The Palm Fiber', 5, true),
    Surah(112, 'الإخلاص', 'Al-Ikhlas', 'The Sincerity', 4, true),
    Surah(113, 'الفلق', 'Al-Falaq', 'The Daybreak', 5, true),
    Surah(114, 'الناس', 'An-Nas', 'Mankind', 6, true),
  ];
}

/// One ayah with its translation.
@immutable
class Ayah {
  const Ayah(this.number, this.arabic, this.translation);

  /// Number within its surah, from 1.
  final int number;
  final String arabic;
  final String translation;
}
