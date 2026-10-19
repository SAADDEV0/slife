import 'package:flutter/foundation.dart';

/// A phrase counted with the tasbih.
@immutable
class Dhikr {
  const Dhikr({
    required this.id,
    required this.latin,
    this.arabic = '',
    this.meaning = '',
    this.target = 33,
    this.custom = false,
  });

  final String id;
  final String arabic;

  /// Transliteration, e.g. "SubhanAllah".
  final String latin;
  final String meaning;

  /// Default goal for one round. 0 means no limit.
  final int target;

  /// Added by the user (can be deleted).
  final bool custom;

  Map<String, Object?> toRow() => {
    'id': id,
    'arabic': arabic,
    'latin': latin,
    'meaning': meaning,
    'target': target,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  };

  factory Dhikr.fromRow(Map<String, Object?> r) => Dhikr(
    id: r['id'] as String,
    arabic: r['arabic'] as String? ?? '',
    latin: r['latin'] as String,
    meaning: r['meaning'] as String? ?? '',
    target: r['target'] as int? ?? 33,
    custom: true,
  );

  /// Built-in phrases. The first three form the after-prayer sequence
  /// (33 + 33 + 34 = 100).
  static const presets = <Dhikr>[
    Dhikr(
      id: 'subhanallah',
      arabic: 'سُبْحَانَ ٱللَّٰهِ',
      latin: 'SubhanAllah',
      meaning: 'Glory be to Allah',
      target: 33,
    ),
    Dhikr(
      id: 'alhamdulillah',
      arabic: 'ٱلْحَمْدُ لِلَّٰهِ',
      latin: 'Alhamdulillah',
      meaning: 'All praise is due to Allah',
      target: 33,
    ),
    Dhikr(
      id: 'allahuakbar',
      arabic: 'ٱللَّٰهُ أَكْبَرُ',
      latin: 'Allahu Akbar',
      meaning: 'Allah is the Greatest',
      target: 34,
    ),
    Dhikr(
      id: 'tahlil',
      arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ',
      latin: 'La ilaha illa Allah',
      meaning: 'There is no god but Allah',
      target: 100,
    ),
    Dhikr(
      id: 'istighfar',
      arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
      latin: 'Astaghfirullah',
      meaning: 'I seek forgiveness from Allah',
      target: 100,
    ),
    Dhikr(
      id: 'salawat',
      arabic: 'ٱللَّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
      latin: 'Allahumma salli ʿala Muhammad',
      meaning: 'O Allah, send blessings upon Muhammad',
      target: 100,
    ),
    Dhikr(
      id: 'subhanallahi_wa_bihamdihi',
      arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ',
      latin: 'SubhanAllahi wa bihamdihi',
      meaning: 'Glory and praise be to Allah',
      target: 100,
    ),
    Dhikr(
      id: 'hawqala',
      arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ',
      latin: 'La hawla wa la quwwata illa billah',
      meaning: 'There is no power nor strength except through Allah',
      target: 33,
    ),
  ];

  static const sequenceIds = ['subhanallah', 'alhamdulillah', 'allahuakbar'];
}
