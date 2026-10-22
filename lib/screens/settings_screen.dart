import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/journal_repository.dart';
import '../data/media_storage.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/sync_indicator.dart';
import 'drive_actions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(expandedHeight: 124, title: const Text('Settings')),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          sliver: SliverList.list(
            children: [
              const _ProfileCard(),
              const SizedBox(height: 24),
              const SectionLabel('Backup'),
              const _BackupCard(),
              if (auth.isConfigured) ...[
                const SizedBox(height: 12),
                GroupCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Auto upload'),
                      subtitle: const Text('Back up changes automatically'),
                      value: settings.autoSync,
                      onChanged: settings.setAutoSync,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.wifi_rounded),
                      title: const Text('Wi‑Fi only'),
                      subtitle: const Text('Save mobile data'),
                      value: settings.wifiOnly,
                      onChanged: settings.setWifiOnly,
                    ),
                    ListTile(
                      enabled: auth.isSignedIn,
                      leading: const Icon(
                        Icons.settings_backup_restore_rounded,
                      ),
                      title: const Text('Restore from Drive'),
                      subtitle: const Text(
                        'Download what is missing on this phone',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Restore from Drive?',
                          message:
                              'Days, plans, tasks, tasbih history and bookmarks from your SLife folder '
                              'that are missing on this phone will be downloaded. '
                              'Nothing already here is changed.',
                          confirm: 'Restore',
                        );
                        if (ok && context.mounted) await runRestore(context);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const SectionLabel('Appearance'),
              PillTabs<ThemeMode>(
                values: const [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ],
                selected: settings.themeMode,
                onChanged: settings.setThemeMode,
                labelOf: (m) => switch (m) {
                  ThemeMode.system => 'System',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                },
                iconOf: (m) => switch (m) {
                  ThemeMode.system => Icons.brightness_auto_outlined,
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.dark => Icons.dark_mode_outlined,
                },
              ),
              const SizedBox(height: 24),
              const SectionLabel('On this phone'),
              const _StorageCard(),
              const SizedBox(height: 24),
              const SectionLabel('About'),
              GroupCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Drive folder'),
                    subtitle: Text(
                      '${AppConfig.driveRootFolder} › one folder per day › '
                      'journal.txt, images, videos, audios',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Privacy'),
                    subtitle: const Text(
                      'Your journal lives on this phone and in your own Drive. '
                      'SLife only sees the files it creates.',
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Version'),
                    trailing: Text('1.0.0'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Center(child: SLifeLogo(size: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();
    final name = settings.userName.isNotEmpty
        ? settings.userName
        : (auth.user?.displayName ?? '');
    final photo = auth.user?.photoUrl;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    Future<void> editName() async {
      final value = await promptText(
        context,
        title: 'Your name',
        initial: settings.userName,
        hint: 'What should SLife call you?',
      );
      if (value != null) await settings.setUserName(value);
    }

    return SurfaceCard(
      onTap: editName,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: c.primarySoft,
            foregroundImage: photo == null ? null : NetworkImage(photo),
            child: Text(
              initial,
              style: context.text.titleLarge?.copyWith(color: c.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Add your name' : name,
                  style: context.text.titleMedium?.copyWith(
                    color: name.isEmpty ? c.primary : c.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  auth.user?.email ?? 'Not connected to Google',
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, color: c.muted, size: 20),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    context.watch<JournalRepository>();
    final pending = sync.pendingCount;

    if (!auth.isConfigured) {
      return SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: c.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Drive is not set up',
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your OAuth client ID in lib/config.dart (see README). '
                    'Until then everything stays safely on this phone.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!auth.isSignedIn) {
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined, color: c.muted),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not backed up', style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Connect Google Drive to keep a copy of every day.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: auth.busy ? null : () => connectDrive(context),
              icon: auth.busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.muted,
                      ),
                    )
                  : const Icon(Icons.add_to_drive_outlined, size: 20),
              label: const Text('Connect Google Drive'),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 10),
              Text(
                auth.error!,
                style: context.text.bodySmall?.copyWith(color: c.danger),
              ),
            ],
          ],
        ),
      );
    }

    final look = syncLook(context, sync, pending);
    final lastSync = sync.lastSyncAt;
    final needsAuth = sync.state == SyncState.needsAuth;
    return GroupCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SyncIcon(icon: look.icon, color: look.color, spin: look.spin),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sync.statusTitle, style: context.text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          sync.isSyncing && sync.currentLabel != null
                              ? sync.currentLabel!
                              : lastSync == null
                              ? 'Not backed up yet'
                              : 'Last backup ${Dates.relative(lastSync)}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: sync.isSyncing || sync.isRestoring
                        ? null
                        : () async {
                            if (needsAuth && !await auth.reauthorize()) return;
                            await sync.syncNow(manual: true);
                          },
                    child: Text(needsAuth ? 'Allow' : 'Back up'),
                  ),
                ],
              ),
              if (sync.isSyncing) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: sync.progress,
                    minHeight: 4,
                  ),
                ),
              ],
              if (sync.state == SyncState.error && sync.lastError != null) ...[
                const SizedBox(height: 10),
                Text(
                  sync.lastError!,
                  style: context.text.bodySmall?.copyWith(color: c.danger),
                ),
              ],
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('Google account'),
          subtitle: Text(auth.user?.email ?? ''),
          trailing: TextButton(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Disconnect Google Drive?',
                message:
                    'Your journal stays on this phone and in your Drive. New changes '
                    'will not be backed up until you connect again.',
                confirm: 'Disconnect',
                destructive: true,
              );
              if (ok) await auth.disconnect();
            },
            child: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }
}

class _StorageCard extends StatefulWidget {
  const _StorageCard();

  @override
  State<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<_StorageCard> {
  int? _bytes;
  int _forCount = -1;

  void _measure(int mediaCount) {
    if (mediaCount == _forCount) return;
    _forCount = mediaCount;
    context.read<MediaStorage>().usedBytes().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalRepository>();
    _measure(journal.mediaCount);
    Widget row(IconData icon, String title, String value) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(value, style: context.text.titleSmall),
    );
    return GroupCard(
      children: [
        row(
          Icons.auto_stories_outlined,
          'Days written',
          '${journal.entries.length}',
        ),
        row(
          Icons.perm_media_outlined,
          'Photos, videos & voice notes',
          '${journal.mediaCount}',
        ),
        row(
          Icons.sd_storage_outlined,
          'Space used',
          _bytes == null ? '…' : MediaStorage.formatBytes(_bytes!),
        ),
      ],
    );
  }
}
