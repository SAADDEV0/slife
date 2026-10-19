import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'drive_actions.dart';

/// First launch: what SLife does, and one tap to start.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context) =>
      context.read<SettingsService>().setOnboarded(true);

  Future<void> _connect(BuildContext context) async {
    if (await connectDrive(context) && context.mounted) await _finish(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final busy = context.watch<AuthService>().busy;

    return Scaffold(
      backgroundColor: c.card,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 2),
                    const SizedBox(height: 32),
                    const SLifeLogo(size: 64, showWordmark: false),
                    const SizedBox(height: 24),
                    Text('Welcome to SLife', style: context.text.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Your life, one day at a time.',
                      style: context.text.bodyLarge?.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 36),
                    const _Feature(
                      icon: Icons.edit_note_rounded,
                      title: 'Write your day',
                      subtitle: 'A page for every day, with your mood and a gentle prompt.',
                    ),
                    const _Feature(
                      icon: Icons.photo_library_outlined,
                      title: 'Keep every moment',
                      subtitle: 'Add photos, videos and voice notes. They all show up in your album.',
                    ),
                    const _Feature(
                      icon: Icons.cloud_done_outlined,
                      title: 'Backed up to your Drive',
                      subtitle: 'Saved on your phone first, then uploaded automatically.',
                    ),
                    const Spacer(flex: 3),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => _connect(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        icon: busy
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
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: busy ? null : () => _finish(context),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        child: const Text('Continue without backup'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'SLife only sees the files it creates in your Drive.',
                        style: context.text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: c.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
