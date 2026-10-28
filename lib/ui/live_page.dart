import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/net.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'player_screen.dart';
import 'widgets.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});
  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  String _cat = '*';
  String _query = '';
  LiveChannel? _selected;

  List<LiveChannel> _channels(AppState s) {
    var list = _cat == 'fav' ? s.favoriteChannels : s.liveIn(_cat);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q) || '${c.num}' == q).toList();
    }
    return list;
  }

  void _play(List<LiveChannel> list, int i) =>
      PlayerScreen.open(context, list.map(PlayItem.fromChannel).toList(), i);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final cats = [
      const MapEntry('*', 'الكل'),
      const MapEntry('fav', 'المفضلة'),
      ...s.library.liveCats.map((e) => MapEntry(e.id, e.name)),
    ];
    final list = _channels(s);

    final search = TextField(
      onChanged: (v) => setState(() => _query = v.trim()),
      decoration: fieldDecoration(context, hint: 'ابحث برقم أو اسم القناة', prefix: const Icon(Icons.search_rounded)),
    );

    final channelList = list.isEmpty
        ? EmptyState(icon: Icons.live_tv_outlined, text: s.loading ? 'جارٍ التحميل…' : 'لا توجد قنوات')
        : ListView.builder(
            itemCount: list.length,
            itemExtent: 62,
            itemBuilder: (_, i) {
              final ch = list[i];
              final sel = wide && _selected?.id == ch.id;
              return Material(
                color: sel ? c.active : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => wide ? setState(() => _selected = ch) : _play(list, i),
                  onDoubleTap: () => _play(list, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      SizedBox(
                          width: 38,
                          child: Text(ch.num > 0 ? '${ch.num}' : '', style: TextStyle(fontSize: 12, color: c.faint))),
                      NetImage(ch.logo, width: 42, height: 42, fit: BoxFit.contain),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(ch.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        tooltip: s.isFav(ch.id) ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                        onPressed: () => s.toggleFav(ch.id),
                        icon: Icon(s.isFav(ch.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: s.isFav(ch.id) ? c.accent : c.faint, size: 20),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('البث المباشر', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          search,
          const SizedBox(height: 12),
          CategoryChips(items: cats, selected: _cat, onSelect: (id) => setState(() => _cat = id)),
          const SizedBox(height: 8),
          Expanded(child: channelList),
        ]),
      );
    }

    final selected = _selected != null && list.any((e) => e.id == _selected!.id) ? _selected : (list.isEmpty ? null : list.first);

    return Row(children: [
      Container(
        width: 240,
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
        decoration: BoxDecoration(color: c.rail, border: BorderDirectional(end: BorderSide(color: c.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: Text('البث المباشر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final e = cats[i];
                final on = e.key == _cat;
                final count = e.key == '*'
                    ? s.library.live.length
                    : e.key == 'fav'
                        ? s.favorites.length
                        : s.library.live.where((x) => x.categoryId == e.key).length;
                return Material(
                  color: on ? c.active : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _cat = e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(children: [
                        Expanded(
                          child: Text(e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: on ? c.text : c.muted, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
                        ),
                        Text('$count', style: TextStyle(fontSize: 12, color: c.faint)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      Container(
        width: 400,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
        decoration: BoxDecoration(border: BorderDirectional(end: BorderSide(color: c.line))),
        child: Column(children: [search, const SizedBox(height: 14), Expanded(child: channelList)]),
      ),
      Expanded(
        child: selected == null
            ? const EmptyState(icon: Icons.tv_rounded, text: 'اختر قناة للمعاينة')
            : _PreviewPanel(
                key: ValueKey(selected.id),
                channel: selected,
                onFullscreen: () => _play(list, list.indexWhere((e) => e.id == selected.id).clamp(0, list.length - 1)),
              ),
      ),
    ]);
  }
}

class _PreviewPanel extends StatefulWidget {
  final LiveChannel channel;
  final VoidCallback onFullscreen;
  const _PreviewPanel({super.key, required this.channel, required this.onFullscreen});
  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  late Future<List<EpgEntry>> _epg;

  @override
  void initState() {
    super.initState();
    _player.open(Media(widget.channel.url, httpHeaders: const {'User-Agent': kUserAgent}));
    _epg = context.read<AppState>().source!.epg(widget.channel);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final ch = widget.channel;
    return ListView(padding: const EdgeInsets.fromLTRB(28, 84, 28, 24), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: Colors.black),
            Video(controller: _video, controls: NoVideoControls),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: c.live, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('مباشر', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: IconButton.filled(
                tooltip: 'ملء الشاشة',
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                onPressed: () {
                  _player.pause();
                  widget.onFullscreen();
                },
                icon: const Icon(Icons.fullscreen_rounded),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: Text('${ch.num > 0 ? '${ch.num} · ' : ''}${ch.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        IconButton.filledTonal(
          tooltip: s.isFav(ch.id) ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
          onPressed: () => s.toggleFav(ch.id),
          icon: Icon(s.isFav(ch.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: c.accent),
        ),
      ]),
      const SizedBox(height: 14),
      FutureBuilder<List<EpgEntry>>(
        future: _epg,
        builder: (_, snap) {
          final list = snap.data ?? const <EpgEntry>[];
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          }
          if (list.isEmpty) {
            return Text('لا يتوفر دليل برامج لهذه القناة', style: TextStyle(color: c.faint));
          }
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              for (var i = 0; i < list.length && i < 6; i++) ...[
                if (i > 0) Divider(color: c.line, height: 20),
                EpgRow(e: list[i]),
              ],
            ]),
          );
        },
      ),
    ]);
  }
}

class EpgRow extends StatelessWidget {
  final EpgEntry e;
  const EpgRow({super.key, required this.e});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = e.isNow;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: now ? c.accent : Colors.transparent,
          border: now ? null : Border.all(color: c.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(now ? 'الآن' : fmtTime(e.start),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: now ? c.onAccent : c.muted)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${fmtTime(e.start)} – ${fmtTime(e.end)}', style: TextStyle(fontSize: 12, color: c.muted)),
          if (now) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: e.progress, minHeight: 4, color: c.accent, backgroundColor: c.line),
          ],
        ]),
      ),
    ]);
  }
}
