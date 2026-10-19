import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';

/// Signs in to Google, grants Drive access and — when the Drive already holds
/// an SLife journal — offers to restore it. Returns true when connected.
Future<bool> connectDrive(BuildContext context) async {
  final auth = context.read<AuthService>();
  final sync = context.read<SyncService>();
  final messenger = ScaffoldMessenger.of(context);

  if (!auth.isConfigured) {
    await showDriveSetupHelp(context);
    return false;
  }
  final ok = await auth.connect();
  if (!context.mounted) return ok;
  if (!ok) {
    final error = auth.error;
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
    return false;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Connected to Google Drive as ${auth.user?.email ?? 'you'}',
      ),
    ),
  );

  try {
    final restorable = await sync.countRestorableDays();
    if (restorable > 0 && context.mounted) {
      final restore = await confirmDialog(
        context,
        title: 'Welcome back!',
        message:
            'Your SLife folder on Google Drive has $restorable '
            '${restorable == 1 ? 'day' : 'days'} that are not on this phone yet. '
            'Download them now?',
        confirm: 'Restore',
      );
      if (restore && context.mounted) await runRestore(context);
    }
  } catch (e) {
    debugPrint('SLife: could not check for an existing backup: $e');
  }
  sync.schedule(const Duration(seconds: 1));
  return true;
}

/// Runs a restore while showing a progress dialog.
Future<void> runRestore(BuildContext context) async {
  final sync = context.read<SyncService>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  final future = sync.restoreFromDrive();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        const PopScope(canPop: false, child: _RestoreProgressDialog()),
  );
  try {
    final result = await future;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.days == 0
              ? 'Everything in Drive is already on this phone.'
              : 'Restored ${result.days} ${result.days == 1 ? 'day' : 'days'} '
                    'and ${result.files} ${result.files == 1 ? 'file' : 'files'}.',
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
  } finally {
    navigator.pop();
  }
}

Future<void> showDriveSetupHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.add_to_drive_rounded,
        color: ctx.colors.primary,
        size: 36,
      ),
      title: const Text('One-time setup needed'),
      content: const Text(
        'To back up to Google Drive, SLife needs an OAuth client ID from your own '
        'Google Cloud project.\n\n'
        'Follow the steps in README.md → “Connect Google Drive”, then rebuild the app. '
        'Until then, everything is safely saved on this phone.',
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _RestoreProgressDialog extends StatelessWidget {
  const _RestoreProgressDialog();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final c = context.colors;
    final total = sync.restoreTotal;
    final done = sync.restoreDone;
    return AlertDialog(
      icon: Icon(Icons.cloud_download_rounded, color: c.primary, size: 36),
      title: const Text('Restoring your journal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? null : done / total,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            total == 0
                ? (sync.restoreLabel ?? 'Connecting…')
                : '$done of $total days',
            style: context.text.titleSmall,
          ),
          if (total > 0 && sync.restoreLabel != null) ...[
            const SizedBox(height: 4),
            Text(sync.restoreLabel!, style: context.text.bodySmall),
          ],
          const SizedBox(height: 10),
          Text(
            'Photos and videos can take a while. Keep SLife open.',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
