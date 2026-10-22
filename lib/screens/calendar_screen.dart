import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/journal_repository.dart';
import '../models/journal_entry.dart';
import '../models/mood.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/entry_card.dart';
import 'routes.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = Dates.today();
  DateTime _selected = Dates.today();

  void _goToToday() => setState(() {
    _focused = Dates.today();
    _selected = Dates.today();
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final journal = context.watch<JournalRepository>();
    final selectedKey = Dates.key(_selected);
    final selectedEntry = journal.entryFor(selectedKey);
    final monthEntries = journal.entries
        .where(
          (e) => e.date.year == _focused.year && e.date.month == _focused.month,
        )
        .toList();
    final onToday =
        isSameDay(_selected, Dates.today()) &&
        _focused.year == _selected.year &&
        _focused.month == _selected.month;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          expandedHeight: 124,
          title: const Text('Calendar'),
          actions: [
            if (!onToday)
              TextButton(onPressed: _goToToday, child: const Text('Today')),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          sliver: SliverList.list(
            children: [
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: TableCalendar<void>(
                  firstDay: DateTime.utc(2000),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focused,
                  currentDay: Dates.today(),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  availableGestures: AvailableGestures.horizontalSwipe,
                  rowHeight: 48,
                  daysOfWeekHeight: 28,
                  selectedDayPredicate: (day) => isSameDay(day, _selected),
                  onDaySelected: (selected, focused) => setState(() {
                    _selected = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    );
                    _focused = focused;
                  }),
                  onPageChanged: (focused) =>
                      setState(() => _focused = focused),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleTextFormatter: (date, _) =>
                        DateFormat('MMMM y').format(date),
                    titleTextStyle: context.text.titleMedium!,
                    headerPadding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                    leftChevronIcon: Icon(
                      Icons.chevron_left_rounded,
                      color: c.ink,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right_rounded,
                      color: c.ink,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    dowTextFormatter: (date, _) =>
                        DateFormat('E').format(date).substring(0, 1),
                    weekdayStyle: context.text.labelSmall!,
                    weekendStyle: context.text.labelSmall!,
                  ),
                  calendarStyle: const CalendarStyle(outsideDaysVisible: false),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (_, day, _) => _DayCell(
                      day: day,
                      entry: journal.entryFor(Dates.key(day)),
                    ),
                    todayBuilder: (_, day, _) => _DayCell(
                      day: day,
                      entry: journal.entryFor(Dates.key(day)),
                      isToday: true,
                    ),
                    selectedBuilder: (_, day, _) => _DayCell(
                      day: day,
                      entry: journal.entryFor(Dates.key(day)),
                      selected: true,
                      isToday: isSameDay(day, Dates.today()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MonthSummary(entries: monthEntries, journal: journal),
              const SizedBox(height: 24),
              SectionLabel(
                Dates.isToday(selectedKey) ? 'Today' : Dates.compact(_selected),
              ),
              if (selectedEntry != null)
                EntryCard(
                  entry: selectedEntry,
                  onTap: () => openDay(context, selectedKey),
                )
              else
                _EmptyDay(
                  day: _selected,
                  onWrite: () => openDay(context, selectedKey),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entry,
    this.selected = false,
    this.isToday = false,
  });

  final DateTime day;
  final JournalEntry? entry;
  final bool selected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final has = entry != null;
    final future = Dates.isFuture(DateTime(day.year, day.month, day.day));
    final Color textColor = selected
        ? c.onPrimary
        : isToday
        ? c.primary
        : future
        ? c.muted.withValues(alpha: 0.55)
        : c.ink;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? c.primary : null,
          border: isToday && !selected
              ? Border.all(color: c.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: context.text.labelLarge?.copyWith(
                color: textColor,
                fontSize: 14,
                fontWeight: has || isToday || selected
                    ? FontWeight.w700
                    : FontWeight.w400,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !has
                    ? Colors.transparent
                    : selected
                    ? c.onPrimary
                    : (entry!.mood?.color ?? c.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Days written, memories and the mood mix of the visible month.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.entries, required this.journal});

  final List<JournalEntry> entries;
  final JournalRepository journal;

  @override
  Widget build(BuildContext context) {
    final counts = <Mood, int>{};
    var memories = 0;
    for (final e in entries) {
      final mood = e.mood;
      if (mood != null) counts[mood] = (counts[mood] ?? 0) + 1;
      memories += journal.mediaFor(e.day).length;
    }
    final top = counts.isEmpty
        ? null
        : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: context.text.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      child: Column(
        children: [
          Row(
            children: [
              stat('${entries.length}', entries.length == 1 ? 'day' : 'days'),
              stat('$memories', memories == 1 ? 'memory' : 'memories'),
              stat(
                top?.emoji ?? '–',
                top == null
                    ? 'no moods yet'
                    : 'mostly ${top.label.toLowerCase()}',
              ),
            ],
          ),
          if (counts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 2,
                    children: [
                      for (final mood in Mood.values)
                        if ((counts[mood] ?? 0) > 0)
                          Expanded(
                            flex: counts[mood]!,
                            child: Tooltip(
                              message: '${mood.label}: ${counts[mood]}',
                              child: ColoredBox(color: mood.color),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day, required this.onWrite});

  final DateTime day;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final future = Dates.isFuture(day);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        children: [
          Text(
            future ? 'This day is still ahead' : 'Nothing written yet',
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            future
                ? 'Come back when it arrives.'
                : 'Remember something about this day? Write it down.',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (!future) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onWrite,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Write about this day'),
            ),
          ],
        ],
      ),
    );
  }
}
