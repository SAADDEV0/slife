import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../models/journal_entry.dart';
import '../models/media_item.dart';
import '../models/mood.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/prompts.dart';
import '../widgets/audio_tile.dart';
import '../widgets/dialogs.dart';
import '../widgets/media_thumb.dart';
import '../widgets/mood_picker.dart';
import '../widgets/voice_recorder_sheet.dart';
import 'routes.dart';

/// What to do right after the editor opens (shortcuts from the home screen).
enum EditorAction { none, camera, video, gallery, voice }

/// The page of one day: mood, title, story, photos, videos and voice notes.
/// Everything is saved automatically.
class EntryEditorScreen extends StatefulWidget {
  const EntryEditorScreen({
    super.key,
    required this.day,
    this.initialAction = EditorAction.none,
  });

  final String day;
  final EditorAction initialAction;

  @override
  State<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends State<EntryEditorScreen> {
  late final JournalRepository _journal = context.read<JournalRepository>();
  final _picker = ImagePicker();
  final _bodyFocus = FocusNode();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final bool _startEmpty;
  late String _lastTitle;
  late String _lastBody;
  Mood? _mood;
  Timer? _debounce;
  bool _unsaved = false;
  bool _deleted = false;
  String? _busy;

  DateTime get _date => Dates.parse(widget.day);

  @override
  void initState() {
    super.initState();
    final entry = _journal.entryFor(widget.day);
    _startEmpty = entry == null;
    _lastTitle = entry?.title ?? '';
    _lastBody = entry?.body ?? '';
    _title = TextEditingController(text: _lastTitle)
      ..addListener(_onTextChanged);
    _body = TextEditingController(text: _lastBody)..addListener(_onTextChanged);
    _mood = entry?.mood;
    if (widget.initialAction != EditorAction.none) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _run(widget.initialAction),
      );
    }
  }

  @override
  void dispose() {
    _flushOnExit();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- saving --

  void _onTextChanged() {
    if (_title.text == _lastTitle && _body.text == _lastBody) return;
    _lastTitle = _title.text;
    _lastBody = _body.text;
    _markUnsaved();
  }

  void _markUnsaved() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _save);
    if (!_unsaved) setState(() => _unsaved = true);
  }

  Future<void> _save() async {
    _debounce?.cancel();
    if (_deleted) return;
    await _journal.saveEntry(
      widget.day,
      title: _title.text,
      body: _body.text,
      mood: _mood,
    );
    if (mounted) setState(() => _unsaved = false);
  }

  /// Saves whatever is left when the page closes, and drops empty days.
  void _flushOnExit() {
    _debounce?.cancel();
    if (_deleted) return;
    final journal = _journal;
    final day = widget.day;
    journal
        .saveEntry(day, title: _title.text, body: _body.text, mood: _mood)
        .then((_) => journal.deleteIfEmpty(day));
  }

  // -------------------------------------------------------------- media --

  Future<void> _run(EditorAction action) async {
    switch (action) {
      case EditorAction.camera:
        await _takePhoto();
      case EditorAction.video:
        await _recordVideo();
      case EditorAction.gallery:
        await _pickFromGallery();
      case EditorAction.voice:
        await _recordVoice();
      case EditorAction.none:
        break;
    }
  }

  Future<void> _takePhoto() async {
    final file = await _guardPick(
      () => _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 3000,
      ),
    );
    if (file != null) await _import([file], type: MediaType.image);
  }

  Future<void> _recordVideo() async {
    final file = await _guardPick(
      () => _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      ),
    );
    if (file != null) await _import([file], type: MediaType.video);
  }

  Future<void> _pickFromGallery() async {
    final files = await _guardPick(
      () => _picker.pickMultipleMedia(imageQuality: 90, maxWidth: 3000),
    );
    if (files != null && files.isNotEmpty) await _import(files);
  }

  Future<void> _recordVoice() async {
    FocusScope.of(context).unfocus();
    await _save();
    if (!mounted) return;
    final recording = await showVoiceRecorder(context, day: widget.day);
    if (recording == null) return;
    await _journal.addRecording(widget.day, recording.path, recording.duration);
  }

  Future<T?> _guardPick<T>(Future<T?> Function() pick) async {
    FocusScope.of(context).unfocus();
    try {
      return await pick();
    } on PlatformException catch (e) {
      _toast(
        e.code.contains('access_denied')
            ? 'SLife does not have permission to use the camera or photos.'
            : 'Could not open: ${e.message ?? e.code}',
      );
      return null;
    }
  }

  Future<void> _import(List<XFile> files, {MediaType? type}) async {
    await _save(); // Make sure the day exists with the latest text.
    for (var i = 0; i < files.length; i++) {
      if (!mounted) return;
      setState(
        () => _busy = files.length == 1
            ? 'Adding…'
            : 'Adding ${i + 1} of ${files.length}…',
      );
      final file = files[i];
      try {
        await _journal.addMediaFile(
          widget.day,
          type ?? (_isVideo(file) ? MediaType.video : MediaType.image),
          file.path,
        );
      } catch (e) {
        _toast('Could not add ${file.name}');
      }
    }
    if (mounted) setState(() => _busy = null);
  }

  static bool _isVideo(XFile file) {
    final mime = file.mimeType ?? lookupMimeType(file.path) ?? '';
    if (mime.startsWith('video/')) return true;
    const videoExtensions = {
      '.mp4',
      '.mov',
      '.m4v',
      '.3gp',
      '.webm',
      '.mkv',
      '.avi',
    };
    return videoExtensions.contains(p.extension(file.path).toLowerCase());
  }

  Future<void> _confirmDeleteMedia(MediaItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this ${item.type.label.toLowerCase()}?',
      message: item.isSynced
          ? 'It will be removed from this phone and moved to the trash in your Google Drive.'
          : 'It will be removed from this phone.',
      confirm: 'Delete',
      destructive: true,
    );
    if (ok) await _journal.deleteMedia(item);
  }

  Future<void> _deleteDay() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this day?',
      message:
          'The text, photos, videos and voice notes of ${Dates.long(_date)} will be removed '
          'from this phone and moved to the trash in your Google Drive.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    _deleted = true;
    _debounce?.cancel();
    await _journal.deleteEntry(widget.day);
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------- UI --

  InputDecoration _bare(String hint, TextStyle? style) => InputDecoration(
    hintText: hint,
    hintStyle: style?.copyWith(
      color: context.colors.muted.withValues(alpha: 0.7),
    ),
    hintMaxLines: 4,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    isCollapsed: true,
    contentPadding: EdgeInsets.zero,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final journal = context.watch<JournalRepository>();
    final entry = journal.entryFor(widget.day);
    final media = journal.mediaFor(widget.day);
    final visual = media.where((m) => m.isVisual).toList();
    final audio = media.where((m) => m.type == MediaType.audio).toList();
    final synced =
        entry != null &&
        !entry.dirty &&
        !_unsaved &&
        media.every((m) => m.isSynced);
    final titleStyle = context.text.headlineSmall;
    final bodyStyle = context.text.bodyLarge?.copyWith(
      fontSize: 17,
      height: 1.65,
    );

    return Scaffold(
      backgroundColor: c.card,
      appBar: AppBar(
        backgroundColor: c.card,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Dates.isToday(widget.day) ? 'Today' : Dates.weekday(_date),
              style: context.text.titleMedium,
            ),
            Text(
              Dates.long(_date),
              style: context.text.labelMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
        actions: [
          _SaveStatus(exists: entry != null, saving: _unsaved, synced: synced),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'delete') _deleteDay();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                enabled: entry != null,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: c.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text('Delete day', style: TextStyle(color: c.danger)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: SizedBox(
            height: 2,
            child: _busy == null
                ? null
                : const LinearProgressIndicator(minHeight: 2),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    Text('Mood', style: context.text.labelMedium),
                    if (_mood != null)
                      Text(
                        ' · ${_mood!.label}',
                        style: context.text.labelMedium?.copyWith(
                          color: _mood!.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                MoodPicker(
                  value: _mood,
                  onChanged: (mood) {
                    HapticFeedback.selectionClick();
                    setState(() => _mood = mood);
                    _markUnsaved();
                  },
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _title,
                  style: titleStyle,
                  decoration: _bare('Title', titleStyle),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLines: null,
                  onSubmitted: (_) => _bodyFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  focusNode: _bodyFocus,
                  autofocus:
                      _startEmpty && widget.initialAction == EditorAction.none,
                  style: bodyStyle,
                  decoration: _bare(Prompts.forDay(_date), bodyStyle),
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 4,
                  maxLines: null,
                ),
                if (visual.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _Header(title: 'Photos & videos', count: visual.length),
                  _MediaGallery(
                    items: visual,
                    onOpen: (index) => openMediaViewer(
                      context,
                      items: visual,
                      initialIndex: index,
                      heroPrefix: 'editor',
                      showOpenDay: false,
                    ),
                    onLongPress: _confirmDeleteMedia,
                  ),
                ],
                if (audio.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _Header(title: 'Voice notes', count: audio.length),
                  for (final item in audio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AudioTile(
                        key: ValueKey(item.id),
                        item: item,
                        onDelete: () => _confirmDeleteMedia(item),
                      ),
                    ),
                ],
              ],
            ),
          ),
          _Toolbar(
            words: JournalEntry.countWords(_body.text),
            enabled: _busy == null,
            onCamera: _takePhoto,
            onVideo: _recordVideo,
            onGallery: _pickFromGallery,
            onVoice: _recordVoice,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title, style: context.text.titleSmall),
          const SizedBox(width: 6),
          Text('$count', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Subtle save/backup state in the app bar.
class _SaveStatus extends StatelessWidget {
  const _SaveStatus({
    required this.exists,
    required this.saving,
    required this.synced,
  });

  final bool exists;
  final bool saving;
  final bool synced;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Widget icon, String label) = saving
        ? (
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.muted),
            ),
            'Saving',
          )
        : !exists
        ? (const SizedBox.shrink(), '')
        : synced
        ? (
            Icon(Icons.cloud_done_outlined, size: 18, color: c.success),
            'Saved and backed up',
          )
        : (
            Icon(Icons.check_circle_outline_rounded, size: 18, color: c.muted),
            'Saved on this phone',
          );
    if (label.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(label), child: icon),
        ),
      ),
    );
  }
}

/// 1 item → wide, 2 → side by side, more → 3-column grid.
class _MediaGallery extends StatelessWidget {
  const _MediaGallery({
    required this.items,
    required this.onOpen,
    required this.onLongPress,
  });

  final List<MediaItem> items;
  final ValueChanged<int> onOpen;
  final ValueChanged<MediaItem> onLongPress;

  Widget _tile(int index, {int cacheWidth = 420}) {
    final item = items[index];
    return GestureDetector(
      onTap: () => onOpen(index),
      onLongPress: () => onLongPress(item),
      child: MediaThumb(
        item: item,
        radius: 12,
        cacheWidth: cacheWidth,
        heroTag: 'editor-${item.id}',
        showSyncBadge: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: _tile(0, cacheWidth: 1080),
      );
    }
    if (items.length == 2) {
      return Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _tile(0, cacheWidth: 600),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _tile(1, cacheWidth: 600),
            ),
          ),
        ],
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (var i = 0; i < items.length; i++) _tile(i)],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.words,
    required this.enabled,
    required this.onCamera,
    required this.onVideo,
    required this.onGallery,
    required this.onVoice,
  });

  final int words;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onGallery;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Take a photo',
                onPressed: enabled ? onCamera : null,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: 'Record a video',
                onPressed: enabled ? onVideo : null,
                icon: const Icon(Icons.videocam_outlined),
              ),
              IconButton(
                tooltip: 'Add from gallery',
                onPressed: enabled ? onGallery : null,
                icon: const Icon(Icons.photo_library_outlined),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: 'Record a voice note',
                onPressed: enabled ? onVoice : null,
                icon: const Icon(Icons.mic_none_rounded),
              ),
              const Spacer(),
              Text(
                '$words ${words == 1 ? 'word' : 'words'}',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
