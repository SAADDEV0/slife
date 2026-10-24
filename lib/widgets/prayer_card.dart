import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../services/prayer_times.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';
import 'dialogs.dart';

/// Asks the OS to let SLife post notifications. Shows how to fix it when
/// blocked. Returns whether reminders can be turned on.
Future<bool> allowNotifications(BuildContext context) async {
  final allowed =
      await context.read<NotificationService?>()?.requestPermission() ?? false;
  if (!allowed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are blocked. Allow them for SLife in your phone '
          'settings.',
        ),
      ),
    );
  }
  return allowed;
}

/// "1 h 05 min" / "12 min" / "now"
String _countdown(Duration d) {
  final m = d.inMinutes + (d.inSeconds % 60 > 0 ? 1 : 0);
  if (m <= 0) return 'now';
  if (m < 60) return 'in $m min';
  return 'in ${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}

/// Today's prayer times with the next one highlighted, or a prompt to set a
/// location. Each prayer has a bell to turn its notification on or off.
class PrayerCard extends StatefulWidget {
  const PrayerCard({super.key});

  @override
  State<PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<PrayerCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps the countdown and the highlighted prayer current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _toggleBell(SettingsService s, Salah p) async {
    final muted = {...s.prayerMuted};
    if (!s.prayerReminder) {
      if (!await allowNotifications(context)) return;
      // Turning reminders on from one bell: start with just that prayer.
      await s.setPrayerMuted({
        for (final o in Salah.values)
          if (o.isPrayer && o != p) o.name,
      });
      await s.setPrayerReminder(true);
      return;
    }
    if (!muted.remove(p.name)) muted.add(p.name);
    await s.setPrayerMuted(muted);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    final c = context.colors;
    final now = DateTime.now();
    final today = DayPrayers.of(s, now);

    if (today == null) {
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: Icons.access_time_rounded, color: c.emerald),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prayer times', style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Set your city once. Times are calculated on the '
                        'phone and work offline.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _LocationButtons(),
          ],
        ),
      );
    }

    final (nextSalah, nextAt) = DayPrayers.next(s, now)!;
    final muted = s.prayerMuted;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${nextSalah.labelOn(nextAt)} ${_countdown(nextAt.difference(now))}',
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: c.muted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${PrayerLocation.label(s)} · '
                            '${PrayerMethod.of(s).label}',
                            style: context.text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Prayer settings',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => showPrayerSetup(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in Salah.values)
            _PrayerRow(
              salah: p,
              label: p.labelOn(now),
              at: today[p],
              isNext: p == nextSalah && Dates.key(nextAt) == Dates.key(now),
              passed: !today[p].isAfter(now),
              bell: p.isPrayer
                  ? s.prayerReminder && !muted.contains(p.name)
                  : null,
              onBell: () => _toggleBell(s, p),
            ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.salah,
    required this.label,
    required this.at,
    required this.isNext,
    required this.passed,
    required this.bell,
    required this.onBell,
  });

  final Salah salah;
  final String label;
  final DateTime at;
  final bool isNext;
  final bool passed;

  /// Whether this prayer notifies; null for sunrise (no bell).
  final bool? bell;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = isNext ? c.emerald : (passed ? c.muted : c.ink);
    final weight = isNext ? FontWeight.w700 : FontWeight.w500;
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 2),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: isNext ? c.emeraldSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                color: fg,
                fontWeight: weight,
              ),
            ),
          ),
          Text(
            salah.arabic,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(
              fontSize: 16,
              color: fg.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: Text(
              Dates.time(at),
              textAlign: TextAlign.end,
              style: context.text.bodyMedium?.copyWith(
                color: fg,
                fontWeight: weight,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 40,
            child: bell == null
                ? null
                : IconButton(
                    tooltip: bell!
                        ? 'Turn off $label reminder'
                        : 'Remind me at $label',
                    iconSize: 20,
                    color: bell! ? c.emerald : c.muted,
                    icon: Icon(
                      bell!
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                    ),
                    onPressed: onBell,
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Use my location" and "Search city" side by side.
class _LocationButtons extends StatefulWidget {
  const _LocationButtons();

  @override
  State<_LocationButtons> createState() => _LocationButtonsState();
}

class _LocationButtonsState extends State<_LocationButtons> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function(SettingsService) find) async {
    final s = context.read<SettingsService>();
    setState(() => _busy = true);
    final error = await find(s);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _search() async {
    final city = await promptText(
      context,
      title: 'Your city',
      hint: 'e.g. Casablanca or Lyon, France',
      confirm: 'Search',
    );
    if (city == null || city.trim().isEmpty) return;
    await _run((s) => PrayerLocation.search(s, city));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _run(PrayerLocation.useCurrent),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 20),
            label: const Text('My location'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _search,
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text('Search city'),
          ),
        ),
      ],
    );
  }
}

/// Location, calculation method and Asr rule.
Future<void> showPrayerSetup(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _PrayerSetup(),
  );
}

class _PrayerSetup extends StatelessWidget {
  const _PrayerSetup();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    final c = context.colors;
    final method = PrayerMethod.of(s);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          Text('Prayer times', style: context.text.titleLarge),
          const SizedBox(height: 16),
          const SectionLabel('Location'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.place_outlined, color: c.emerald),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        PrayerLocation.label(s),
                        style: context.text.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _LocationButtons(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Asr'),
          PillTabs<bool>(
            values: const [false, true],
            selected: s.prayerHanafi,
            onChanged: s.setPrayerHanafi,
            labelOf: (h) => h ? 'Hanafi' : 'Standard',
            iconOf: (h) =>
                h ? Icons.wb_twilight_rounded : Icons.wb_sunny_outlined,
          ),
          const SizedBox(height: 20),
          const SectionLabel('Calculation method'),
          GroupCard(
            children: [
              for (final m in PrayerMethod.values)
                ListTile(
                  title: Text(m.label),
                  subtitle: Text(m.detail),
                  trailing: m == method
                      ? Icon(Icons.check_rounded, color: c.emerald)
                      : null,
                  onTap: () => s.setPrayerMethod(m.name),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Times are calculated on your phone and can differ by a few '
            'minutes from your local mosque. Pick the method your country '
            'uses.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Opens [showPrayerSetup] when no location is set yet. Returns whether one
/// is set afterwards.
Future<bool> ensurePrayerLocation(BuildContext context) async {
  final s = context.read<SettingsService>();
  if (s.prayerLat != null) return true;
  final ok = await confirmDialog(
    context,
    title: 'Where are you?',
    message: 'Prayer times depend on your city. Set it once to continue.',
    confirm: 'Set city',
  );
  if (!ok || !context.mounted) return false;
  await showPrayerSetup(context);
  return s.prayerLat != null;
}
