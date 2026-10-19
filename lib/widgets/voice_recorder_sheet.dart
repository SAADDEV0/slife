import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../data/media_storage.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';

class RecordedAudio {
  const RecordedAudio(this.path, this.duration);
  final String path;
  final Duration duration;
}

/// Records a voice note straight into the day's `audios/` folder.
Future<RecordedAudio?> showVoiceRecorder(
  BuildContext context, {
  required String day,
}) {
  return showModalBottomSheet<RecordedAudio>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => VoiceRecorderSheet(day: day),
  );
}

class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key, required this.day});

  final String day;

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  static const _visibleBars = 56;

  final _recorder = AudioRecorder();
  final _stopwatch = Stopwatch();
  final _levels = List<double>.filled(_visibleBars, 0.06, growable: true);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _path;
  bool _ready = false;
  bool _paused = false;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start(context.read<MediaStorage>());
  }

  Future<void> _start(MediaStorage storage) async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(
          () => _error = 'SLife needs microphone access to record voice notes.',
        );
        return;
      }
      final name = storage.newFileName(MediaType.audio, '.m4a');
      final path = await storage.prepareTarget(
        widget.day,
        MediaType.audio,
        name,
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      HapticFeedback.mediumImpact();
      _path = path;
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen((a) {
            if (_paused || !mounted) return;
            // dBFS → 0..1 (speech sits roughly between -45 and -5 dB).
            final level = ((a.current + 50) / 50).clamp(0.06, 1.0);
            setState(() {
              _levels.add(level);
              if (_levels.length > _visibleBars) _levels.removeAt(0);
            });
          });
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start recording.\n$e');
    }
  }

  Future<void> _togglePause() async {
    if (!_ready) return;
    if (_paused) {
      await _recorder.resume();
      _stopwatch.start();
    } else {
      await _recorder.pause();
      _stopwatch.stop();
    }
    HapticFeedback.selectionClick();
    setState(() => _paused = !_paused);
  }

  Future<void> _finish() async {
    if (!_ready || _finishing) return;
    setState(() => _finishing = true);
    final path = await _recorder.stop() ?? _path;
    _stopwatch.stop();
    if (!mounted) return;
    if (path == null ||
        _stopwatch.elapsed < const Duration(milliseconds: 600)) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(RecordedAudio(path, _stopwatch.elapsed));
  }

  Future<void> _cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              ..._buildError(context)
            else
              ..._buildRecorder(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildError(BuildContext context) {
    return [
      Icon(Icons.mic_off_rounded, size: 44, color: context.colors.danger),
      const SizedBox(height: 14),
      Text(
        _error!,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium,
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _cancel, child: const Text('Close')),
      ),
    ];
  }

  List<Widget> _buildRecorder(BuildContext context) {
    final c = context.colors;
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _paused ? const AlwaysStoppedAnimation(1) : _pulse,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _paused ? c.muted : c.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            !_ready ? 'Getting ready…' : (_paused ? 'Paused' : 'Recording'),
            style: context.text.labelLarge,
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        Dates.duration(_stopwatch.elapsed),
        style: AppTheme.font(
          fontSize: 44,
          fontWeight: FontWeight.w600,
          color: c.ink,
          letterSpacing: -1,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 64,
        width: double.infinity,
        child: CustomPaint(
          painter: WaveformPainter(
            levels: List.of(_levels),
            activeColor: _paused ? c.muted : c.primary,
            inactiveColor: c.line,
            barWidth: 3.5,
            gap: 2.5,
          ),
        ),
      ),
      const SizedBox(height: 28),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SideButton(
            icon: Icons.delete_outline_rounded,
            label: 'Discard',
            onPressed: _finishing ? null : _cancel,
          ),
          Semantics(
            button: true,
            label: 'Save voice note',
            child: Pressable(
              onTap: _ready && !_finishing ? _finish : null,
              scale: 0.92,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
                child: _finishing
                    ? Padding(
                        padding: const EdgeInsets.all(26),
                        child: CircularProgressIndicator(
                          color: c.onPrimary,
                          strokeWidth: 2.6,
                        ),
                      )
                    : Icon(Icons.check_rounded, color: c.onPrimary, size: 36),
              ),
            ),
          ),
          _SideButton(
            icon: _paused ? Icons.mic_rounded : Icons.pause_rounded,
            label: _paused ? 'Resume' : 'Pause',
            onPressed: _ready && !_finishing ? _togglePause : null,
          ),
        ],
      ),
      const SizedBox(height: 8),
    ];
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          tooltip: label,
          style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
          icon: Icon(icon),
        ),
        const SizedBox(height: 6),
        Text(label, style: context.text.labelMedium),
      ],
    );
  }
}
