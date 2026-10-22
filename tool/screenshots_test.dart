// Renders SLife's main screens with sample data into docs/screenshots/.
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// Uses local system fonts (Windows) as stand-ins for the Google Fonts the
// app downloads at runtime, so the output is close to — not identical with —
// the real app.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:slife/data/journal_repository.dart';
import 'package:slife/data/planner_repository.dart';
import 'package:slife/data/quran_repository.dart';
import 'package:slife/data/tasbih_repository.dart';
import 'package:slife/models/planner.dart';
import 'package:slife/screens/deen_screen.dart';
import 'package:slife/screens/planner_screen.dart';
import 'package:slife/screens/quran_reader_screen.dart';
import 'package:slife/screens/tasbih_view.dart';
import 'package:slife/data/media_storage.dart';
import 'package:slife/models/journal_entry.dart';
import 'package:slife/models/media_item.dart';
import 'package:slife/models/mood.dart';
import 'package:slife/screens/album_screen.dart';
import 'package:slife/screens/calendar_screen.dart';
import 'package:slife/screens/entry_editor_screen.dart';
import 'package:slife/screens/home_shell.dart';
import 'package:slife/screens/onboarding_screen.dart';
import 'package:slife/screens/settings_screen.dart';
import 'package:slife/services/auth_service.dart';
import 'package:slife/services/settings_service.dart';
import 'package:slife/services/sync_service.dart';
import 'package:slife/theme/app_theme.dart';
import 'package:slife/utils/dates.dart';

const _size = Size(390, 844);
const _out = '../docs/screenshots';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      if (File(f).existsSync()) {
        loader.addFont(
          File(f).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      }
    }
    await loader.load();
  }

  const fonts = 'C:/Windows/Fonts';
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/saad/develop/flutter';
  await load('SLifeSerif', ['$fonts/georgia.ttf', '$fonts/georgiab.ttf']);
  await load('SLifeSans', [
    '$fonts/segoeui.ttf',
    '$fonts/seguisb.ttf',
    '$fonts/segoeuib.ttf',
  ]);
  await load('SLifeEmoji', ['$fonts/seguiemj.ttf']);
  await load('Amiri', [
    'assets/fonts/Amiri-Regular.ttf',
    'assets/fonts/Amiri-Bold.ttf',
  ]);
  await load('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

/// Paints a little landscape "photo".
Future<void> _paintPhoto(String path, int seed) async {
  const palettes = [
    [
      Color(0xFFFFB37A),
      Color(0xFFFF6F91),
      Color(0xFFFFE29A),
      Color(0xFF6B3E75),
      Color(0xFF3C2352),
    ],
    [
      Color(0xFF8EC5FC),
      Color(0xFFE0C3FC),
      Color(0xFFFFFFFF),
      Color(0xFF5B7DB1),
      Color(0xFF34507A),
    ],
    [
      Color(0xFFFAD0C4),
      Color(0xFFFFD1FF),
      Color(0xFFFFF4C2),
      Color(0xFF7FB77E),
      Color(0xFF4E8A55),
    ],
    [
      Color(0xFF2E3192),
      Color(0xFF1BFFFF),
      Color(0xFFFFF8D6),
      Color(0xFF1F2A5A),
      Color(0xFF111833),
    ],
    [
      Color(0xFFF6D365),
      Color(0xFFFDA085),
      Color(0xFFFFFFFF),
      Color(0xFFB5651D),
      Color(0xFF7A3E12),
    ],
    [
      Color(0xFFA1C4FD),
      Color(0xFFC2E9FB),
      Color(0xFFFFFDE7),
      Color(0xFF4FA3A5),
      Color(0xFF2D6E70),
    ],
  ];
  final p = palettes[seed % palettes.length];
  const s = 600.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, s), [
        p[0],
        p[1],
      ]),
  );
  canvas.drawCircle(
    Offset(140.0 + (seed * 97) % 320, 210),
    70,
    Paint()..color = p[2],
  );
  final back = Path()
    ..moveTo(0, 400)
    ..quadraticBezierTo(170, 300 + (seed % 3) * 20, 330, 390)
    ..quadraticBezierTo(470, 460, s, 360)
    ..lineTo(s, s)
    ..lineTo(0, s)
    ..close();
  canvas.drawPath(back, Paint()..color = p[3]);
  final front = Path()
    ..moveTo(0, 500)
    ..quadraticBezierTo(220, 420, 420, 500)
    ..quadraticBezierTo(520, 540, s, 480)
    ..lineTo(s, s)
    ..lineTo(0, s)
    ..close();
  canvas.drawPath(front, Paint()..color = p[4]);
  final image = await recorder.endRecording().toImage(s.toInt(), s.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

class _Sample {
  _Sample(this.storage);

  final MediaStorage storage;
  final entries = <JournalEntry>[];
  final media = <MediaItem>[];
  var _seed = 0;

  DateTime _ago(int days) {
    final t = Dates.today();
    return DateTime(t.year, t.month, t.day - days);
  }

  Future<void> day(
    int daysAgo,
    String title,
    String body,
    Mood? mood, {
    int photos = 0,
    int videos = 0,
    int voices = 0,
  }) async {
    final date = _ago(daysAgo);
    final key = Dates.key(date);
    entries.add(
      JournalEntry(
        day: key,
        title: title,
        body: body,
        mood: mood,
        createdAt: date,
        updatedAt: date,
        dirty: false,
      ),
    );
    var minute = 0;
    Future<void> add(MediaType type) async {
      final id = '$key-${_seed++}';
      final item = MediaItem(
        id: id,
        day: key,
        type: type,
        fileName: '${type.prefix}_$id.png',
        thumbName: type == MediaType.video ? 'thumb_$id.png' : null,
        durationMs: type == MediaType.audio ? 42000 + _seed * 7000 : null,
        createdAt: date.add(Duration(hours: 9, minutes: minute += 47)),
        driveFileId: 'drive-$id',
      );
      if (type == MediaType.image) {
        await _paintPhoto(storage.pathFor(item), _seed);
      }
      if (type == MediaType.video) {
        await _paintPhoto(storage.thumbPathFor(item)!, _seed + 2);
      }
      media.add(item);
    }

    for (var i = 0; i < photos; i++) {
      await add(MediaType.image);
    }
    for (var i = 0; i < videos; i++) {
      await add(MediaType.video);
    }
    for (var i = 0; i < voices; i++) {
      await add(MediaType.audio);
    }
  }
}

Future<_Sample> _buildSample(MediaStorage storage) async {
  final s = _Sample(storage);
  await s.day(
    0,
    'Coffee, rain and a good book',
    'Woke up early to the sound of rain on the window. Made a slow coffee and finally '
        'finished the novel I started in September — the ending made me cry a little. '
        'In the afternoon the sky cleared and the whole street smelled like wet leaves.',
    Mood.good,
    photos: 3,
    voices: 1,
  );
  await s.day(
    1,
    'Sunset walk by the sea',
    'We walked along the beach until the sky turned orange and pink. Collected shells, '
        'talked about everything and nothing.',
    Mood.amazing,
    photos: 2,
    videos: 1,
  );
  await s.day(
    2,
    'Long day at work',
    'Back-to-back meetings. Tired, but proud I finished the presentation on time.',
    Mood.low,
  );
  await s.day(
    3,
    'Family dinner',
    'Grandma made her famous couscous. The kids played until midnight.',
    Mood.amazing,
    photos: 4,
    voices: 1,
  );
  await s.day(
    5,
    'Morning run — 5K!',
    'New personal best: 27:40.',
    Mood.good,
    photos: 1,
  );
  await s.day(
    8,
    'Quiet Sunday',
    'Did nothing at all, and it was perfect.',
    Mood.okay,
    voices: 1,
  );
  await s.day(
    12,
    'Market day',
    'Fresh figs, mint and a lot of bargaining.',
    Mood.good,
    photos: 3,
  );
  await s.day(
    15,
    'First day of autumn',
    'Cold air, warm tea.',
    Mood.okay,
    photos: 2,
    videos: 1,
  );
  await s.day(19, 'Rough one', 'Headache all day. Early night.', Mood.rough);
  return s;
}

Widget _app({
  required Widget home,
  required SettingsService settings,
  required MediaStorage storage,
  required JournalRepository journal,
  ThemeMode mode = ThemeMode.light,
  PlannerRepository? planner,
  TasbihRepository? tasbih,
  QuranRepository? quran,
}) {
  final auth = AuthService(settings);
  final sync = SyncService(
    journal: journal,
    auth: auth,
    settings: settings,
    storage: storage,
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      Provider.value(value: storage),
      ChangeNotifierProvider.value(value: journal),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider.value(value: planner ?? _samplePlanner()),
      ChangeNotifierProvider.value(value: tasbih ?? _sampleTasbih()),
      ChangeNotifierProvider.value(value: quran ?? QuranRepository.memory()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: home,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late Directory temp;
  late MediaStorage storage;
  late _Sample sample;

  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    // just_audio is not available in tests; answer its calls with nothing.
    const channels = ['com.ryanheise.just_audio.methods'];
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(name),
            (call) async => <String, dynamic>{},
          );
    }
    temp = await Directory.systemTemp.createTemp('slife_shots');
    storage = MediaStorage(temp.path);
    sample = await _buildSample(storage);
  });

  tearDownAll(() async {
    try {
      await temp.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget home, {
    ThemeMode mode = ThemeMode.light,
    Future<void> Function()? before,
    bool skipToday = false,
    TasbihRepository? tasbih,
    QuranLayout quranLayout = QuranLayout.verses,
  }) async {
    debugDisableShadows = false; // Real, blurred shadows in screenshots.
    tester.view.physicalSize = _size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final today = Dates.todayKey();
    final journal = JournalRepository.preview(
      storage,
      entries: [
        for (final e in sample.entries)
          if (!skipToday || e.day != today) e,
      ],
      media: [
        for (final m in sample.media)
          if (!skipToday || m.day != today) m,
      ],
    );
    final settings = SettingsService.memory(userName: 'Saad');
    await tester.pumpWidget(
      _app(
        home: home,
        settings: settings,
        storage: storage,
        journal: journal,
        mode: mode,
        tasbih: tasbih,
        quran: QuranRepository.memory(lastRead: (2, 255))
          ..setLayout(quranLayout),
      ),
    );
    await _settle(tester);
    if (before != null) {
      await before();
      await _settle(tester);
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/$name.png'),
    );
    debugDisableShadows = true;
  }

  testWidgets(
    'onboarding',
    (t) => shoot(t, '01_onboarding', const OnboardingScreen()),
  );
  testWidgets('journal', (t) => shoot(t, '02_journal', const HomeShell()));
  testWidgets(
    'journal dark',
    (t) => shoot(t, '03_journal_dark', const HomeShell(), mode: ThemeMode.dark),
  );
  testWidgets(
    'editor',
    (t) => shoot(t, '04_day_editor', EntryEditorScreen(day: Dates.todayKey())),
  );
  testWidgets('editor scrolled', (t) async {
    await shoot(
      t,
      '05_day_editor_media',
      EntryEditorScreen(day: Dates.todayKey()),
      before: () async {
        await t.drag(find.byType(ListView), const Offset(0, -520));
      },
    );
  });
  testWidgets(
    'calendar',
    (t) => shoot(t, '06_calendar', const Scaffold(body: CalendarScreen())),
  );
  testWidgets(
    'album',
    (t) => shoot(t, '07_album', const Scaffold(body: AlbumScreen())),
  );
  testWidgets(
    'settings',
    (t) => shoot(t, '08_settings', const Scaffold(body: SettingsScreen())),
  );
  testWidgets(
    'journal before writing today',
    (t) => shoot(t, '10_journal_prompt', const HomeShell(), skipToday: true),
  );
  testWidgets(
    'planner',
    (t) => shoot(t, '11_planner', const Scaffold(body: PlannerScreen())),
  );
  testWidgets(
    'tasks',
    (t) => shoot(
      t,
      '12_tasks',
      const Scaffold(body: PlannerScreen()),
      before: () async {
        await t.tap(find.text('Tasks · 4'));
      },
    ),
  );
  testWidgets(
    'tasbih',
    (t) => shoot(
      t,
      '13_tasbih',
      const Scaffold(body: DeenScreen()),
      before: () async {
        await t.tap(find.text('Tasbih'));
      },
    ),
  );
  testWidgets(
    'quran',
    (t) => shoot(
      t,
      '14_quran',
      const Scaffold(body: DeenScreen()),
      mode: ThemeMode.dark,
    ),
  );
  testWidgets(
    'quran reader',
    (t) => shoot(t, '15_quran_reader', const QuranReaderScreen(surah: 2)),
  );
  testWidgets(
    'quran mushaf dark',
    (t) => shoot(
      t,
      '16_quran_mushaf_dark',
      const QuranReaderScreen(surah: 36),
      mode: ThemeMode.dark,
      quranLayout: QuranLayout.mushaf,
    ),
  );
  testWidgets(
    'album by day',
    (t) => shoot(
      t,
      '17_album_days',
      const Scaffold(body: AlbumScreen()),
      before: () async {
        await t.tap(find.byTooltip('View'));
        await t.pumpAndSettle();
        await t.tap(find.text('By day'));
      },
    ),
  );
  testWidgets(
    'tasks dark',
    (t) => shoot(
      t,
      '18_tasks_dark',
      const Scaffold(body: PlannerScreen()),
      mode: ThemeMode.dark,
      before: () async {
        await t.tap(find.text('Tasks · 4'));
      },
    ),
  );
  testWidgets(
    'task sheet dark',
    (t) => shoot(
      t,
      '19_task_sheet_dark',
      const Scaffold(body: PlannerScreen()),
      mode: ThemeMode.dark,
      before: () async {
        await t.tap(find.text('Tasks · 4'));
        await t.pumpAndSettle();
        await t.tap(find.text('Call the bank'));
      },
    ),
  );
  testWidgets(
    'tasbih focus',
    (t) => shoot(t, '20_tasbih_focus', const TasbihFocusScreen()),
  );
  testWidgets(
    'album dark',
    (t) => shoot(
      t,
      '09_album_dark',
      const Scaffold(body: AlbumScreen()),
      mode: ThemeMode.dark,
    ),
  );
}

PlannerRepository _samplePlanner() {
  final today = Dates.todayKey();
  final now = DateTime.now();
  final nowMin = now.hour * 60 + now.minute;
  final start = (nowMin ~/ 60) * 60;
  var i = 0;
  PlanBlock block(
    int from,
    int to,
    String title,
    int color, {
    bool done = false,
    String note = '',
  }) {
    return PlanBlock(
      id: 'b${i++}',
      day: today,
      startMin: (from).clamp(0, 24 * 60 - 30),
      endMin: (to).clamp(30, 24 * 60),
      title: title,
      note: note,
      color: color,
      done: done,
      createdAt: now,
    );
  }

  final blocks = [
    block(start - 180, start - 120, 'Fajr & morning adhkar', 2, done: true),
    block(
      start - 120,
      start,
      'Deep work: SLife release',
      0,
      done: true,
      note: 'Finish the planner screen',
    ),
    block(start, start + 60, 'Team call', 1),
    block(start + 60, start + 90, 'Lunch & Dhuhr', 3),
    block(start + 120, start + 210, 'Gym', 4),
  ];
  final tomorrow = Dates.key(Dates.today().add(const Duration(days: 1)));
  final tasks = [
    Task(
      id: 't1',
      title: 'Call the bank',
      dueDay: today,
      priority: TaskPriority.high,
      createdAt: now,
    ),
    Task(
      id: 't2',
      title: 'Buy groceries',
      dueDay: today,
      note: 'Milk, dates, bread',
      createdAt: now,
    ),
    Task(
      id: 't3',
      title: 'Read 10 pages',
      dueDay: tomorrow,
      priority: TaskPriority.medium,
      createdAt: now,
    ),
    Task(id: 't4', title: 'Plan the weekend trip', createdAt: now),
    Task(
      id: 't5',
      title: 'Reply to Yassine',
      dueDay: today,
      done: true,
      createdAt: now,
      completedAt: now,
    ),
  ];
  return PlannerRepository.memory(blocks: blocks, tasks: tasks);
}

TasbihRepository _sampleTasbih() {
  final today = Dates.today();
  final log = <String, Map<String, int>>{};
  const counts = [100, 33, 0, 166, 99, 133, 0];
  for (var i = 0; i < counts.length; i++) {
    final d = Dates.key(DateTime(today.year, today.month, today.day - 6 + i));
    if (counts[i] > 0) log[d] = {'subhanallah': counts[i]};
  }
  final repo = TasbihRepository.memory(log: log);
  for (var i = 0; i < 21; i++) {
    repo.increment();
  }
  return repo;
}
