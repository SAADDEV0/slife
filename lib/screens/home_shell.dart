import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../services/notification_service.dart';
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
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    final notifications = context.read<NotificationService?>();
    _taps = notifications?.taps.listen(_openReminder);
    final launch = notifications?.takeLaunchPayload();
    if (launch != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openReminder(launch),
      );
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  /// Opens what a tapped reminder points to (`journal:<day>`,
  /// `planner:<day>` or `deen:<day>`).
  void _openReminder(String payload) {
    if (!mounted) return;
    final (kind, day) = switch (payload.split(':')) {
      [final k, final d] => (k, d),
      _ => (payload, Dates.todayKey()),
    };
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (kind == 'journal') {
      _select(0);
      openDay(context, day);
    } else if (kind == 'planner') {
      _select(1);
    } else if (kind == 'deen') {
      _select(2);
    }
  }

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
    final hasToday = context.select<JournalRepository, bool>(
      (j) => j.entryFor(Dates.todayKey()) != null,
    );

    return Scaffold(
      extendBody: true,
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
      bottomNavigationBar: _FloatingNav(
        index: _index,
        onSelect: _select,
        items: const [
          _NavItem(
            Icons.auto_stories_outlined,
            Icons.auto_stories_rounded,
            'Journal',
          ),
          _NavItem(
            Icons.event_note_outlined,
            Icons.event_note_rounded,
            'Planner',
          ),
          _NavItem(Icons.mosque_outlined, Icons.mosque_rounded, 'Deen'),
          _NavItem(
            Icons.calendar_month_outlined,
            Icons.calendar_month_rounded,
            'Calendar',
          ),
          _NavItem(
            Icons.photo_library_outlined,
            Icons.photo_library_rounded,
            'Album',
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A floating, rounded navigation bar; pages scroll underneath it.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? bottom : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.line.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: context.isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0x1F1B1530),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => onSelect(i),
                      radius: 34,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: i == index ? 52 : 36,
                            height: 30,
                            decoration: BoxDecoration(
                              color: i == index
                                  ? c.primarySoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              i == index
                                  ? items[i].selectedIcon
                                  : items[i].icon,
                              size: 22,
                              color: i == index ? c.primary : c.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[i].label,
                            maxLines: 1,
                            style: context.text.labelSmall?.copyWith(
                              fontSize: 11,
                              color: i == index ? c.ink : c.muted,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
