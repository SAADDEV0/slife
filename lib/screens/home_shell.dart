import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'album_screen.dart';
import 'calendar_screen.dart';
import 'deen_screen.dart';
import 'journal_screen.dart';
import 'planner_screen.dart';
import 'routes.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _fabExtended = true;

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      _fabExtended = true;
    });
  }

  /// Shrinks the Write button while scrolling down, expands it going up.
  bool _onScroll(UserScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final extended = switch (n.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasToday = context.select<JournalRepository, bool>(
      (j) => j.entryFor(Dates.todayKey()) != null,
    );

    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: IndexedStack(
          index: _index,
          children: [
            JournalScreen(
              onOpenSettings: () => openSettings(context),
              onOpenTab: _select,
            ),
            const PlannerScreen(),
            const DeenScreen(),
            const CalendarScreen(),
            const AlbumScreen(),
          ],
        ),
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              heroTag: 'write',
              tooltip: hasToday ? 'Continue today' : 'Write today',
              onPressed: () => openDay(context, Dates.todayKey()),
              icon: const Icon(Icons.edit_outlined),
              extendedIconLabelSpacing: _fabExtended ? 8 : 0,
              extendedPadding: EdgeInsets.symmetric(
                horizontal: _fabExtended ? 20 : 16,
              ),
              label: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: _fabExtended
                    ? Text(hasToday ? 'Continue' : 'Write')
                    : const SizedBox.shrink(),
              ),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded),
              label: 'Journal',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Planner',
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque_rounded),
              label: 'Deen',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library_rounded),
              label: 'Album',
            ),
          ],
        ),
      ),
    );
  }
}
