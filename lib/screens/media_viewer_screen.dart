import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../data/journal_repository.dart';
import '../data/media_storage.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/dialogs.dart';
import 'routes.dart';

/// Full-screen, swipeable photo & video viewer.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.heroPrefix,
    this.showOpenDay = true,
  });

  final List<MediaItem> items;
  final int initialIndex;
  final String? heroPrefix;
  final bool showOpenDay;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late final List<MediaItem> _items = List.of(widget.items);
  late int _index = widget.initialIndex;
  bool _chrome = true;

  MediaItem get _current => _items[_index];

  void _toggleChrome() => setState(() => _chrome = !_chrome);

  Future<void> _delete() async {
    final item = _current;
    final ok = await confirmDialog(
      context,
      title: 'Delete this ${item.type.label.toLowerCase()}?',
      message: item.isSynced
          ? 'It will be removed from this phone and moved to the trash in your Google Drive.'
          : 'It will be removed from this phone.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<JournalRepository>().deleteMedia(item);
    if (!mounted) return;
    if (_items.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<MediaStorage>();
    final item = _current;
    final date = Dates.parse(item.day);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final m = _items[i];
                final heroTag = widget.heroPrefix == null
                    ? null
                    : '${widget.heroPrefix}-${m.id}';
                if (m.type == MediaType.video) {
                  return _VideoPage(
                    key: ValueKey(m.id),
                    item: m,
                    active: i == _index,
                    onTap: _toggleChrome,
                    chromeVisible: _chrome,
                  );
                }
                return PhotoView(
                  key: ValueKey(m.id),
                  imageProvider: FileImage(storage.fileFor(m)),
                  heroAttributes: heroTag == null
                      ? null
                      : PhotoViewHeroAttributes(tag: heroTag),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  onTapUp: (_, _, _) => _toggleChrome(),
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                );
              },
            ),
            // Top bar
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !_chrome,
                child: AnimatedOpacity(
                  opacity: _chrome ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 20),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Dates.compact(date),
                                    style: context.text.titleSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${item.type.label} · ${Dates.time(item.createdAt)}'
                                    '${item.isSynced ? ' · in Drive' : ''}',
                                    style: context.text.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.showOpenDay)
                              TextButton(
                                onPressed: () => openDay(context, item.day),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Open day'),
                              ),
                            IconButton(
                              onPressed: _delete,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_items.length > 1 && item.type == MediaType.image)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _chrome ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_index + 1} / ${_items.length}',
                              style: context.text.labelMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    super.key,
    required this.item,
    required this.active,
    required this.onTap,
    required this.chromeVisible,
  });

  final MediaItem item;
  final bool active;
  final VoidCallback onTap;
  final bool chromeVisible;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final storage = context.read<MediaStorage>();
    final controller = VideoPlayerController.file(storage.fileFor(widget.item));
    _controller = controller;
    controller.addListener(_onTick);
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.active) controller.play();
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (!widget.active && old.active) c.pause();
    if (widget.active && !old.active) c.play();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<MediaStorage>();
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final thumb = storage.thumbPathFor(widget.item);

    if (_failed) {
      return const Center(
        child: Text(
          'This video could not be played.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!ready && thumb != null)
            Image.file(
              File(thumb),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
          if (ready)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            ),
          if (!ready)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (ready)
            Center(
              child: AnimatedOpacity(
                opacity: c.value.isPlaying && !widget.chromeVisible ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      c.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: widget.chromeVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Row(
                        children: [
                          Text(
                            Dates.duration(c.value.position),
                            style: context.text.labelMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: VideoProgressIndicator(
                                c,
                                allowScrubbing: true,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                colors: VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white.withValues(
                                    alpha: 0.25,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Dates.duration(c.value.duration),
                            style: context.text.labelMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
