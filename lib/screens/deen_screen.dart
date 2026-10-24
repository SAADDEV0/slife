import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/hijri.dart';
import '../widgets/common.dart';
import '../widgets/prayer_card.dart';
import 'quran_view.dart';
import 'tasbih_view.dart';

enum _Section { quran, tasbih }

/// Faith: prayer times, the Quran and the digital tasbih.
class DeenScreen extends StatefulWidget {
  const DeenScreen({super.key});

  @override
  State<DeenScreen> createState() => _DeenScreenState();
}

class _DeenScreenState extends State<DeenScreen> {
  _Section _section = _Section.quran;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(expandedHeight: 124, title: const Text('Deen')),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(child: _DateHero()),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(child: PrayerCard()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          sliver: SliverToBoxAdapter(
            child: PillTabs<_Section>(
              values: _Section.values,
              selected: _section,
              onChanged: (s) => setState(() => _section = s),
              labelOf: (s) => s == _Section.quran ? 'Quran' : 'Tasbih',
              iconOf: (s) => s == _Section.quran
                  ? Icons.menu_book_rounded
                  : Icons.radio_button_checked_rounded,
            ),
          ),
        ),
        if (_section == _Section.quran)
          const QuranView()
        else
          const TasbihView(),
        const SliverToBoxAdapter(child: BottomSpace()),
      ],
    );
  }
}

/// Today's Hijri date over an emerald gradient with a geometric motif.
class _DateHero extends StatelessWidget {
  const _DateHero();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = HijriDate.fromGregorian(now);
    const fg = Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.isDark
                ? const [Color(0xFF0F5C49), Color(0xFF123A4E)]
                : const [Color(0xFF0E8F6E), Color(0xFF136A8A)],
          ),
        ),
        child: CustomPaint(
          painter: _StarPattern(color: Colors.white.withValues(alpha: 0.08)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assalamu alaikum',
                        style: context.text.labelMedium?.copyWith(
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${h.day} ${h.monthName}',
                        style: context.text.headlineSmall?.copyWith(color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${h.year} AH · ${Dates.header(now)}',
                        style: context.text.bodySmall?.copyWith(
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      h.monthArabic,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.arabic(
                        fontSize: 26,
                        color: const Color(0xFFFFE3A6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'approx.',
                      style: context.text.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Eight-pointed stars, the classic Islamic geometric motif.
class _StarPattern extends CustomPainter {
  const _StarPattern({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const r = 22.0;
    for (var y = -r; y < size.height + r; y += r * 2.4) {
      for (var x = size.width * 0.45; x < size.width + r; x += r * 2.4) {
        final c = Offset(x, y);
        final square = Rect.fromCenter(
          center: c,
          width: r * 1.4,
          height: r * 1.4,
        );
        canvas.drawRect(square, paint);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.785398);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.4, height: r * 1.4),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_StarPattern old) => old.color != color;
}
