import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/journal_repository.dart';
import 'data/media_storage.dart';
import 'data/planner_repository.dart';
import 'data/quran_repository.dart';
import 'data/tasbih_repository.dart';
import 'services/auth_service.dart';
import 'services/life_backup.dart';
import 'services/settings_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Local first: the journal is fully usable before any network call.
  final settings = await SettingsService.load();
  final storage = await MediaStorage.create();
  final db = await AppDatabase.open();
  final journal = JournalRepository(db, storage);
  final planner = PlannerRepository(db);
  final tasbih = TasbihRepository(db);
  final quran = QuranRepository(db, p.join(storage.rootPath, 'quran'));
  final life = LifeBackup(
    planner: planner,
    tasbih: tasbih,
    quran: quran,
    settings: settings,
  );
  await Future.wait([
    journal.load(),
    planner.load(),
    tasbih.load(),
    quran.load(),
  ]);

  final auth = AuthService(settings);
  final sync = SyncService(
    journal: journal,
    auth: auth,
    settings: settings,
    storage: storage,
    life: life,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: planner),
        ChangeNotifierProvider.value(value: tasbih),
        ChangeNotifierProvider.value(value: quran),
      ],
      child: const SLifeApp(),
    ),
  );

  sync.start();
  await auth.init();
}
