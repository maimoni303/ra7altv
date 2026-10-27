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
        if (widget.items.length > 1) ...[
          IconButton(
            tooltip: _item.isLive ? 'القناة السابقة' : 'السابق',
            color: Colors.white,
            onPressed: _index > 0 ? () => _go(_index - 1) : null,
            icon: const Icon(Icons.skip_next_rounded), // RTL: "previous" points right
          ),
          IconButton(
            tooltip: _item.isLive ? 'القناة التالية' : 'التالي',
            color: Colors.white,
            onPressed: _index < widget.items.length - 1 ? () => _go(_index + 1) : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
        ],
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
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(fit: StackFit.expand, children: [
            MaterialVideoControlsTheme(
              normal: MaterialVideoControlsThemeData(
                topButtonBar: _topBar(),
                seekBarPositionColor: accent,
                seekBarThumbColor: accent,
                seekOnDoubleTap: !_item.isLive,
              ),
              fullscreen: MaterialVideoControlsThemeData(
                seekBarPositionColor: accent,
                seekBarThumbColor: accent,
              ),
              child: MaterialDesktopVideoControlsTheme(
                normal: MaterialDesktopVideoControlsThemeData(
                  topButtonBar: _topBar(),
                  seekBarPositionColor: accent,
                  seekBarThumbColor: accent,
                ),
                fullscreen: MaterialDesktopVideoControlsThemeData(
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
