import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/prompts.dart';
import '../widgets/common.dart';
import '../widgets/entry_card.dart';
import '../widgets/sync_indicator.dart';
import 'entry_editor_screen.dart';
import 'routes.dart';
import 'search_screen.dart';
import 'today_card.dart';

/// Home: this week at a glance, today's prompt and every written day.
class JournalScreen extends StatelessWidget {
  const JournalScreen({
    super.key,
    required this.onOpenSettings,
    this.onOpenTab,
  });

  final VoidCallback onOpenSettings;

  /// Switches the home tab (1 = Planner, 2 = Deen).
  final ValueChanged<int>? onOpenTab;

  Future<void> _backUp(BuildContext context) async {
    final auth = context.read<AuthService>();
    final sync = context.read<SyncService>();
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.isSignedIn) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Your journal is saved on this phone.'),
            action: SnackBarAction(
              label: 'Set up backup',
              onPressed: onOpenSettings,
            ),
          ),
        );
      return;
    }
    await sync.syncNow(manual: true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(sync.statusTitle)));
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalRepository>();
    final todayKey = Dates.todayKey();
    final writtenToday = journal.entryFor(todayKey) != null;

    final timeline = <Widget>[];
    String? month;
    for (final entry in journal.entries) {
      final label = Dates.month(entry.date);
      if (label != month) {
        month = label;
        timeline.add(
          SectionLabel(
            label,
            padding: EdgeInsets.fromLTRB(4, timeline.isEmpty ? 0 : 14, 4, 10),
          ),
        );
      }
      timeline.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EntryCard(
            entry: entry,
            onTap: () => openDay(context, entry.day),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _backUp(context),
      edgeOffset: MediaQuery.paddingOf(context).top + 64,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            expandedHeight: 124,
            title: const Text('Journal'),
            actions: [
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                ),
              ),
              SyncStatusButton(onPressed: () => _backUp(context)),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: onOpenSettings,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList.list(
              children: [
                const _WeekCard(),
                const SizedBox(height: 12),
                if (onOpenTab != null) ...[
                  TodayCard(onOpenTab: onOpenTab!),
                  const SizedBox(height: 12),
                ],
                if (!writtenToday) ...[
                  const _PromptCard(),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                if (journal.isEmpty)
                  const EmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'Your journal is empty',
                    message: 'Write your first page. You can add photos, videos and voice notes too.',
                  )
                else
                  ...timeline,
                const BottomSpace(extra: 88),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The last seven days: tap any day to open it.
class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final journal = context.watch<JournalRepository>();
    final today = Dates.today();
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final streak = journal.streak;
    final thisMonth = journal.entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .length;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: streak > 0 ? c.accent : c.muted,
              ),
              const SizedBox(width: 6),
              Text(
                streak > 0 ? '$streak-day streak' : 'Start a streak today',
                style: context.text.titleSmall,
              ),
              const Spacer(),
              Text('$thisMonth this month', style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayDot(
                  day: day,
                  written: journal.entryFor(Dates.key(day)) != null,
                  isToday: day == today,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.written,
    required this.isToday,
  });

  final DateTime day;
  final bool written;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weekday = Dates.shortWeekday(day);
    return Semantics(
      button: true,
      label: '${Dates.weekday(day)}${written ? ', written' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openDay(context, Dates.key(day)),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            children: [
              Text(
                weekday.substring(0, 1),
                style: context.text.labelSmall?.copyWith(
                  color: isToday ? c.primary : c.muted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: written ? c.primary : c.cardAlt,
                  border: isToday && !written
                      ? Border.all(color: c.primary, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: written
                    ? Icon(Icons.check_rounded, size: 18, color: c.onPrimary)
                    : Text(
                        '${day.day}',
                        style: context.text.labelMedium?.copyWith(
                          color: isToday ? c.primary : c.muted,
                          fontWeight: FontWeight.w600,
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

/// Shown until today has been written: a prompt plus quick actions.
class _PromptCard extends StatelessWidget {
  const _PromptCard();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();
    final name = settings.userName.isNotEmpty
        ? settings.userName.split(' ').first
        : (auth.user?.displayName?.split(' ').first ?? '');
    final today = Dates.todayKey();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Dates.greeting()}${name.isEmpty ? '' : ', $name'}',
            style: context.text.labelMedium,
          ),
          const SizedBox(height: 6),
          Text(
            Prompts.forDay(Dates.today()),
            style: context.text.titleLarge?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openDay(context, today),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Start writing'),
                ),
              ),
              const SizedBox(width: 8),
              _QuickAction(
                icon: Icons.photo_camera_outlined,
                tooltip: 'Take a photo',
                onPressed: () =>
                    openDay(context, today, action: EditorAction.camera),
              ),
              const SizedBox(width: 8),
              _QuickAction(
                icon: Icons.mic_none_rounded,
                tooltip: 'Record a voice note',
                onPressed: () =>
                    openDay(context, today, action: EditorAction.voice),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
