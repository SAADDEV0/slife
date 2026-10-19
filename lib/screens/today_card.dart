import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/planner_repository.dart';
import '../data/tasbih_repository.dart';
import '../models/planner.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

/// Today at a glance on the journal home: the plan, open tasks and dhikr.
/// Each row jumps to its tab.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.onOpenTab});

  /// 1 = Planner, 2 = Deen.
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final planner = context.watch<PlannerRepository>();
    final tasbih = context.watch<TasbihRepository>();
    final today = Dates.todayKey();
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    final blocks = planner.blocksFor(today);
    PlanBlock? current, next;
    for (final b in blocks) {
      if (b.done) continue;
      if (b.startMin <= nowMin && nowMin < b.endMin) {
        current ??= b;
      } else if (b.startMin > nowMin) {
        next ??= b;
      }
    }
    final (String planTitle, String planDetail) = switch ((current, next)) {
      (final PlanBlock b, _) => (
        b.title,
        'Now · until ${PlanBlock.clock(b.endMin)}',
      ),
      (null, final PlanBlock b) => (
        b.title,
        'Next · ${PlanBlock.clock(b.startMin)}',
      ),
      _ when blocks.isEmpty => ('Plan your day', 'Add blocks of time'),
      _ => (
        'Day plan done',
        '${blocks.where((b) => b.done).length} of ${blocks.length} blocks',
      ),
    };

    final due = planner.tasksDue(today);
    final open = due.where((t) => !t.done).length;
    final overdue = due
        .where((t) => !t.done && t.dueDay!.compareTo(today) < 0)
        .length;
    final dhikr = tasbih.todayTotal;

    return GroupCard(
      children: [
        _Row(
          icon: Icons.view_timeline_outlined,
          tint: current?.swatch ?? next?.swatch ?? c.primary,
          title: planTitle,
          detail: planDetail,
          onTap: () => onOpenTab(1),
        ),
        _Row(
          icon: Icons.checklist_rounded,
          tint: overdue > 0 ? c.danger : c.success,
          title: open == 0
              ? 'No tasks left today'
              : '$open ${open == 1 ? 'task' : 'tasks'} left today',
          detail: overdue > 0
              ? '$overdue overdue'
              : (due.isEmpty ? 'Nothing due' : '${due.length - open} done'),
          detailColor: overdue > 0 ? c.danger : null,
          onTap: () => onOpenTab(1),
        ),
        _Row(
          icon: Icons.radio_button_checked_rounded,
          tint: c.accent,
          title: dhikr == 0 ? 'Remember Allah' : '$dhikr dhikr today',
          detail: tasbih.streak > 1
              ? '${tasbih.streak}-day streak'
              : 'Open the tasbih',
          onTap: () => onOpenTab(2),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    required this.onTap,
    this.detailColor,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: context.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: detailColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}
