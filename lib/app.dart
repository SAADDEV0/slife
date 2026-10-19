import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

class SLifeApp extends StatelessWidget {
  const SLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return MaterialApp(
      title: 'SLife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: settings.onboarded
            ? const HomeShell(key: ValueKey('home'))
            : const OnboardingScreen(key: ValueKey('onboarding')),
      ),
    );
  }
}
