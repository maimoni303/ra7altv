import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/net.dart';
import '../state/app_state.dart';
import '../theme.dart';

class PlayItem {
  final String key, title, subtitle, url, image, kind; // kind: live | movie | episode
  final int resumeMs;
  const PlayItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.image,
    required this.kind,
    this.resumeMs = 0,
  });

  bool get isLive => kind == 'live';

  static PlayItem fromChannel(LiveChannel c) => PlayItem(
        key: 'live_${c.id}',
        title: c.name,
        subtitle: c.num > 0 ? 'القناة ${c.num}' : 'بث مباشر',
        url: c.url,
        image: c.logo,
        kind: 'live',
      );

  static PlayItem fromVod(VodItem v, String key, {int resumeMs = 0}) => PlayItem(
        key: key,
        title: v.name,
        subtitle: 'فيلم',
        url: v.url,
        image: v.poster,
        kind: 'movie',
        resumeMs: resumeMs,
      );
}

class PlayerScreen extends StatefulWidget {
  final List<PlayItem> items;
  final int index;
  const PlayerScreen({super.key, required this.items, required this.index});

  static Future<void> open(BuildContext context, List<PlayItem> items, int index) {
    if (items.isEmpty) return Future.value();
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(items: items, index: index.clamp(0, items.length - 1)),
    ));
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024, title: 'RA7AlTV'),
  );
  late final VideoController _video = VideoController(_player);
  final _subs = <StreamSubscription>[];
  late int _index = widget.index;

  Timer? _saveTimer, _reconnectTimer, _watchdog;
  int _attempt = 0;
  String? _status; // reconnecting / error message overlay
  bool _resumed = false;
  DateTime _lastProgress = DateTime.now();
  Duration _lastPos = Duration.zero;

  PlayItem get _item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _configure();
    _subs.addAll([
      _player.stream.error.listen(_onError),
      _player.stream.completed.listen((done) {
        if (!done) return;
        if (_item.isLive) {
          _scheduleReconnect('انقطع البث، جارٍ إعادة الاتصال…');
        } else {
          _saveProgress(finished: true);
          if (_item.kind == 'episode' && _index < widget.items.length - 1) _go(_index + 1);
        }
      }),
      _player.stream.duration.listen((d) {
        if (!_resumed && d > Duration.zero && _item.resumeMs > 0) {
          _resumed = true;
          final target = Duration(milliseconds: _item.resumeMs);
          if (target < d - const Duration(seconds: 30)) _player.seek(target);
        }
      }),
      _player.stream.position.listen((p) {
        if (p != _lastPos) {
          _lastPos = p;
          _lastProgress = DateTime.now();
          if (_status != null && _attempt > 0) {
            _attempt = 0;
            if (mounted) setState(() => _status = null);
          }
        }
      }),
    ]);
    _start();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    // Live watchdog: if the picture freezes for 25 s while "playing", reconnect.
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_item.isLive || !_player.state.playing || _reconnectTimer != null) return;
      if (DateTime.now().difference(_lastProgress) > const Duration(seconds: 25)) {
        _scheduleReconnect('البث متوقف، جارٍ إعادة الاتصال…');
      }
    });
  }

  Future<void> _configure() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      for (final kv in const [
        ['network-timeout', '20'],
        ['tls-verify', 'no'],
        ['cache', 'yes'],
        ['demuxer-readahead-secs', '20'],
        ['stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5'],
      ]) {
        try {
          await platform.setProperty(kv[0], kv[1]);
        } catch (_) {}
      }
    }
  }

  void _start() {
    _resumed = false;
    _lastProgress = DateTime.now();
    _player.open(Media(_item.url, httpHeaders: const {'User-Agent': kUserAgent}));
  }

  void _onError(String e) {
    if (_item.isLive) {
      _scheduleReconnect('تعذّر تشغيل البث، جارٍ إعادة المحاولة…');
    } else if (mounted) {
      setState(() => _status = 'تعذّر التشغيل: $e');
    }
  }

  void _scheduleReconnect(String message) {
    if (_reconnectTimer != null || !mounted) return;
    _attempt++;
    final secs = [2, 4, 8, 15, 20][(_attempt - 1).clamp(0, 4)];
    setState(() => _status = message);
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      _reconnectTimer = null;
      if (!mounted) return;
      _start();
    });
  }

  void _go(int i) {
    if (i < 0 || i >= widget.items.length) return;
    _saveProgress();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    setState(() {
      _index = i;
      _status = null;
      _attempt = 0;
    });
    _start();
  }

  /// Seeks VOD by [secs] (RTL: the left arrow moves forward).
  void _seekBy(int secs) {
    if (_item.isLive) return;
    final d = _player.state.duration;
    var t = _player.state.position + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (d > Duration.zero && t > d) t = d;
    _player.seek(t);
  }

  void _saveProgress({bool finished = false}) {
    if (_item.isLive || !mounted) return;
    final dur = _player.state.duration;
    final pos = finished ? dur : _player.state.position;
    if (dur <= Duration.zero || pos <= Duration.zero) return;
    context.read<AppState>().saveProgress(WatchEntry(
          key: _item.key,
          title: _item.title,
          subtitle: _item.subtitle,
          url: _item.url,
          image: _item.image,
          kind: _item.kind,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
          updatedMs: DateTime.now().millisecondsSinceEpoch,
        ));
  }

  @override
  void dispose() {
    _saveProgress();
    _saveTimer?.cancel();
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }


  // ---- bottom bar: previous / next, audio and subtitles ----
  Widget _barButton(IconData icon, String label, VoidCallback? onPressed) => TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 13)),
      );

  List<Widget> _navButtons() {
    if (widget.items.length < 2) return const [];
    final live = _item.isLive;
    return [
      _barButton(Icons.skip_previous_rounded, live ? 'القناة السابقة' : 'السابقة',
          _index > 0 ? () => _go(_index - 1) : null),
      _barButton(Icons.skip_next_rounded, live ? 'القناة التالية' : 'التالية',
          _index < widget.items.length - 1 ? () => _go(_index + 1) : null),
    ];
  }

  List<Widget> _trackButtons() => [
        _barButton(Icons.audiotrack_rounded, 'الصوت', () => _pickTrack(audio: true)),
        _barButton(Icons.closed_caption_rounded, 'الترجمة', () => _pickTrack(audio: false)),
      ];

  String _trackLabel(String id, String? title, String? lang) {
    if (id == 'auto') return 'تلقائي';
    if (id == 'no') return 'إيقاف';
    final parts = [if (title != null && title.isNotEmpty) title, if (lang != null && lang.isNotEmpty) lang.toUpperCase()];
    return parts.isEmpty ? 'مسار $id' : parts.join(' · ');
  }

  Future<void> _pickTrack({required bool audio}) async {
    final tracks = _player.state.tracks;
    final current = _player.state.track;
    final entries = audio
        ? tracks.audio.map((t) => (id: t.id, label: _trackLabel(t.id, t.title, t.language), on: t == current.audio, apply: () => _player.setAudioTrack(t))).toList()
        : tracks.subtitle.map((t) => (id: t.id, label: _trackLabel(t.id, t.title, t.language), on: t == current.subtitle, apply: () => _player.setSubtitleTrack(t))).toList();
    final accent = Ra7al.dark.accent;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1530),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(audio ? 'الصوت' : 'الترجمة',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          if (entries.length <= 2 && !audio)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('لا توجد ترجمات مضمّنة في هذا الملف', style: TextStyle(color: Color(0xFFA9B4D6))),
            ),
          for (final e in entries)
            ListTile(
              autofocus: e.on,
              title: Text(e.label, style: const TextStyle(color: Colors.white)),
              trailing: e.on ? Icon(Icons.check_rounded, color: accent) : null,
              onTap: () {
                e.apply();
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }

  List<Widget> _topBar() => [
        IconButton(
          tooltip: 'رجوع',
          color: Colors.white,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            Text(_item.subtitle, style: const TextStyle(color: Color(0xFFC8D0EA), fontSize: 13)),
          ]),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final accent = Ra7al.dark.accent;
    final video = Video(controller: _video);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _go(_index + 1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        // TV remote / D-pad
        const SingleActivator(LogicalKeyboardKey.channelUp): () => _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () => _go(_index + 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (_item.isLive) _go(_index - 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (_item.isLive) _go(_index + 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekBy(10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekBy(-10),
        const SingleActivator(LogicalKeyboardKey.select): () => _player.playOrPause(),
        const SingleActivator(LogicalKeyboardKey.enter): () => _player.playOrPause(),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () => _player.playOrPause(),
        const SingleActivator(LogicalKeyboardKey.mediaFastForward): () => _seekBy(30),
        const SingleActivator(LogicalKeyboardKey.mediaRewind): () => _seekBy(-30),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(fit: StackFit.expand, children: [
            MaterialVideoControlsTheme(
              normal: MaterialVideoControlsThemeData(
                topButtonBar: _topBar(),
                primaryButtonBar: [const Spacer(), MaterialPlayOrPauseButton(iconSize: 56), const Spacer()],
                bottomButtonBar: [
                  if (!_item.isLive) MaterialPositionIndicator(),
                  const Spacer(),
                  ..._navButtons(),
                  ..._trackButtons(),
                  MaterialFullscreenButton(),
                ],
                seekBarPositionColor: accent,
                seekBarThumbColor: accent,
                seekOnDoubleTap: !_item.isLive,
              ),
              fullscreen: MaterialVideoControlsThemeData(
                primaryButtonBar: [const Spacer(), MaterialPlayOrPauseButton(iconSize: 56), const Spacer()],
                bottomButtonBar: [
                  if (!_item.isLive) MaterialPositionIndicator(),
                  const Spacer(),
                  ..._navButtons(),
                  ..._trackButtons(),
                  MaterialFullscreenButton(),
                ],
                seekBarPositionColor: accent,
                seekBarThumbColor: accent,
              ),
              child: MaterialDesktopVideoControlsTheme(
                normal: MaterialDesktopVideoControlsThemeData(
                  topButtonBar: _topBar(),
                  bottomButtonBar: [
                    MaterialDesktopPlayOrPauseButton(),
                    MaterialDesktopVolumeButton(),
                    if (!_item.isLive) MaterialDesktopPositionIndicator(),
                    const Spacer(),
                    ..._navButtons(),
                    ..._trackButtons(),
                    MaterialDesktopFullscreenButton(),
                  ],
                  seekBarPositionColor: accent,
                  seekBarThumbColor: accent,
                ),
                fullscreen: MaterialDesktopVideoControlsThemeData(
                  bottomButtonBar: [
                    MaterialDesktopPlayOrPauseButton(),
                    MaterialDesktopVolumeButton(),
                    if (!_item.isLive) MaterialDesktopPositionIndicator(),
                    const Spacer(),
                    ..._navButtons(),
                    ..._trackButtons(),
                    MaterialDesktopFullscreenButton(),
                  ],
                  seekBarPositionColor: accent,
                  seekBarThumbColor: accent,
                ),
                child: SafeArea(child: video),
              ),
            ),
            if (_status != null)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_item.isLive)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                    if (_item.isLive) const SizedBox(width: 12),
                    Flexible(child: Text(_status!, style: const TextStyle(color: Colors.white))),
                    if (!_item.isLive) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          setState(() => _status = null);
                          _start();
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
