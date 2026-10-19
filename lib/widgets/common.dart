import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';

/// The standard SLife surface: a white card with a hairline border and an
/// ink ripple when tappable.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: color ?? c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Scales its child down slightly while pressed.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The SLife mark, optionally followed by the wordmark.
class SLifeLogo extends StatelessWidget {
  const SLifeLogo({super.key, this.size = 32, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: const SLifeMarkPainter(),
    );
    if (!showWordmark) return Semantics(label: 'SLife', child: mark);
    return Semantics(
      label: 'SLife',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(width: size * 0.3),
          Text(
            'SLife',
            style: AppTheme.font(
              fontSize: size * 0.62,
              fontWeight: FontWeight.w700,
              color: context.colors.ink,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small section title above a group of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.text.titleSmall?.copyWith(
                color: context.colors.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Icon + message for empty screens, with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c.primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// A grouped list (settings style): one card, rows separated by dividers.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(indent: 16, endIndent: 16, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Draws audio level bars; bars before [progress] use [activeColor].
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.levels,
    required this.activeColor,
    required this.inactiveColor,
    this.progress = 1,
    this.barWidth = 3,
    this.gap = 3,
  });

  final List<double> levels;
  final Color activeColor;
  final Color inactiveColor;
  final double progress;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final count = (size.width / (barWidth + gap)).floor();
    if (count <= 0) return;
    final active = Paint()..color = activeColor;
    final inactive = Paint()..color = inactiveColor;
    for (var i = 0; i < count; i++) {
      final level =
          levels[(i * levels.length / count).floor().clamp(
            0,
            levels.length - 1,
          )];
      final h = (level.clamp(0.0, 1.0) * size.height).clamp(
        barWidth,
        size.height,
      );
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, (i + 0.5) / count <= progress ? active : inactive);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      old.levels != levels ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}
