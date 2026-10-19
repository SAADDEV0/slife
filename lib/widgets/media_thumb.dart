import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/media_storage.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';

/// Square preview of a photo or video.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.item,
    this.radius = 12,
    this.cacheWidth = 360,
    this.showSyncBadge = false,
    this.heroTag,
  });

  final MediaItem item;
  final double radius;
  final int cacheWidth;
  final bool showSyncBadge;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final storage = context.read<MediaStorage>();
    final path = item.type == MediaType.image
        ? storage.pathFor(item)
        : storage.thumbPathFor(item);

    Widget image = path == null
        ? _Placeholder(type: item.type)
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _Placeholder(type: item.type),
          );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    return Semantics(
      image: true,
      label: item.type.label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (item.type == MediaType.video)
              const Positioned(
                left: 6,
                bottom: 6,
                child: _Chip(icon: Icons.play_arrow_rounded),
              ),
            if (showSyncBadge && !item.isSynced)
              const Positioned(
                top: 6,
                right: 6,
                child: _Chip(icon: Icons.cloud_upload_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 15),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.type});

  final MediaType type;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.cardAlt,
      child: Icon(
        type == MediaType.video ? Icons.movie_outlined : Icons.image_outlined,
        color: context.colors.muted,
      ),
    );
  }
}
