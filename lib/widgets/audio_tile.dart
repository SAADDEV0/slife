import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../data/media_storage.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';

/// Voice note player with a seekable waveform.
class AudioTile extends StatefulWidget {
  const AudioTile({super.key, required this.item, this.onDelete});

  final MediaItem item;
  final VoidCallback? onDelete;

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  late final List<double> _levels = _fakeLevels(widget.item.id);
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _duration = widget.item.duration;
    _subs.add(
      _player.positionStream.listen((p) => setState(() => _position = p)),
    );
    _subs.add(
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _player.pause();
          _player.seek(Duration.zero);
        }
        setState(
          () => _playing =
              s.playing && s.processingState != ProcessingState.completed,
        );
      }),
    );
  }

  /// A stable, pleasant-looking pseudo waveform derived from the id.
  static List<double> _fakeLevels(String seed) {
    final rnd = math.Random(seed.hashCode);
    var last = 0.5;
    return List.generate(48, (i) {
      last = (last * 0.45 + (0.2 + rnd.nextDouble() * 0.8) * 0.55).clamp(
        0.18,
        1.0,
      );
      return last;
    });
  }

  Future<bool> _ensureLoaded() async {
    if (_loaded) return true;
    try {
      final path = context.read<MediaStorage>().pathFor(widget.item);
      final d = await _player.setFilePath(path);
      if (!mounted) return false;
      setState(() {
        _duration = d ?? _duration;
        _loaded = true;
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This voice note could not be played.')),
        );
      }
      return false;
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (!await _ensureLoaded()) return;
    unawaited(_player.play());
  }

  Future<void> _seekTo(double fraction) async {
    final total = _duration;
    if (total == null || total == Duration.zero) return;
    if (!await _ensureLoaded()) return;
    await _player.seek(total * fraction.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: _toggle,
            tooltip: _playing ? 'Pause' : 'Play',
            style: IconButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              fixedSize: const Size(44, 44),
            ),
            icon: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    void seek(Offset local) =>
                        _seekTo(local.dx / constraints.maxWidth);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => seek(d.localPosition),
                      onHorizontalDragUpdate: (d) => seek(d.localPosition),
                      child: SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: WaveformPainter(
                            levels: _levels,
                            progress: progress,
                            activeColor: c.primary,
                            inactiveColor: c.line,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  '${_playing || _position > Duration.zero ? '${Dates.duration(_position)} / ' : ''}'
                  '${Dates.duration(total)} · ${Dates.time(widget.item.createdAt)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (!widget.item.isSynced)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 16,
                color: c.muted,
              ),
            ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: widget.onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: c.muted,
                size: 20,
              ),
              tooltip: 'Delete voice note',
            ),
        ],
      ),
    );
  }
}
