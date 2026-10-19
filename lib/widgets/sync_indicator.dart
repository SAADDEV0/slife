import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

typedef SyncLook = ({IconData icon, Color color, bool spin});

SyncLook syncLook(BuildContext context, SyncService sync, int pending) {
  final c = context.colors;
  return switch (sync.state) {
    SyncState.syncing => (
      icon: Icons.sync_rounded,
      color: c.primary,
      spin: true,
    ),
    SyncState.upToDate => (
      icon: Icons.cloud_done_outlined,
      color: c.success,
      spin: false,
    ),
    SyncState.pending || SyncState.idle =>
      !sync.auth.isSignedIn
          ? (icon: Icons.cloud_off_outlined, color: c.muted, spin: false)
          : pending == 0
          ? (icon: Icons.cloud_done_outlined, color: c.success, spin: false)
          : (icon: Icons.cloud_upload_outlined, color: c.primary, spin: false),
    SyncState.offline => (
      icon: Icons.cloud_off_outlined,
      color: c.muted,
      spin: false,
    ),
    SyncState.waitingForWifi => (
      icon: Icons.wifi_off_rounded,
      color: c.muted,
      spin: false,
    ),
    SyncState.paused => (
      icon: Icons.pause_circle_outline_rounded,
      color: c.muted,
      spin: false,
    ),
    SyncState.signedOut => (
      icon: Icons.cloud_off_outlined,
      color: c.muted,
      spin: false,
    ),
    SyncState.needsAuth => (
      icon: Icons.lock_outline_rounded,
      color: c.danger,
      spin: false,
    ),
    SyncState.error => (
      icon: Icons.error_outline_rounded,
      color: c.danger,
      spin: false,
    ),
  };
}

/// App-bar button showing the backup state, with a badge for pending items.
class SyncStatusButton extends StatelessWidget {
  const SyncStatusButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    context.watch<JournalRepository>();
    final pending = sync.pendingCount;
    final look = syncLook(context, sync, pending);
    final showBadge = sync.auth.isSignedIn && pending > 0 && !sync.isSyncing;
    return IconButton(
      tooltip: sync.statusTitle,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: showBadge,
        label: Text(pending > 99 ? '99+' : '$pending'),
        child: SyncIcon(icon: look.icon, color: look.color, spin: look.spin),
      ),
    );
  }
}

/// An icon that rotates while [spin] is true.
class SyncIcon extends StatefulWidget {
  const SyncIcon({
    super.key,
    required this.icon,
    required this.color,
    this.spin = false,
    this.size = 24,
  });

  final IconData icon;
  final Color color;
  final bool spin;
  final double size;

  @override
  State<SyncIcon> createState() => _SyncIconState();
}

class _SyncIconState extends State<SyncIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spin) _controller.repeat();
  }

  @override
  void didUpdateWidget(SyncIcon old) {
    super.didUpdateWidget(old);
    if (widget.spin && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spin && _controller.isAnimating) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0, end: -1).animate(_controller),
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}
