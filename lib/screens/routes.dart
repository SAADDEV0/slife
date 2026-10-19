import 'package:flutter/material.dart';

import '../models/media_item.dart';
import 'entry_editor_screen.dart';
import 'media_viewer_screen.dart';
import 'settings_screen.dart';

/// Opens the journal page of [day] (`yyyy-MM-dd`) with the platform's native
/// transition (and predictive back on Android).
Future<void> openDay(
  BuildContext context,
  String day, {
  EditorAction action = EditorAction.none,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EntryEditorScreen(day: day, initialAction: action),
    ),
  );
}

Future<void> openMediaViewer(
  BuildContext context, {
  required List<MediaItem> items,
  required int initialIndex,
  String? heroPrefix,
  bool showOpenDay = true,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => MediaViewerScreen(
        items: items,
        initialIndex: initialIndex,
        heroPrefix: heroPrefix,
        showOpenDay: showOpenDay,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

Future<void> openSettings(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: SettingsScreen()),
    ),
  );
}
