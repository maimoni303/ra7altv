import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'player_screen.dart';
import 'vod_page.dart';
import 'widgets.dart';

class SeriesDetails extends StatefulWidget {
  final SeriesItem series;
  const SeriesDetails({super.key, required this.series});
  @override
  State<SeriesDetails> createState() => _SeriesDetailsState();
}

class _SeriesDetailsState extends State<SeriesDetails> {
  SeriesInfo? _info;
  String? _error;
  int? _season;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final info = await context.read<AppState>().source!.seriesInfo(widget.series);
      if (!mounted) return;
      setState(() {
        _info = info;
        _season = info.seasons.keys.isEmpty ? null : info.seasons.keys.first;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _key(AppState s, Episode e) => 'ep_${s.active?.id}_${e.id}';

  List<PlayItem> _playlist(AppState s, List<Episode> eps) => eps
      .map((e) => PlayItem(
            key: _key(s, e),
            title: widget.series.name,
            subtitle: 'الموسم ${e.season} · الحلقة ${e.number}',
            url: e.url,
            image: e.image.isNotEmpty ? e.image : widget.series.cover,
            kind: 'episode',
            resumeMs: (() {
              final p = s.progressFor(_key(s, e));
              return p != null && !p.finished ? p.positionMs : 0;
            })(),
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final info = _info;
    final eps = info == null || _season == null ? const <Episode>[] : info.seasons[_season] ?? const <Episode>[];
    final plot = (info?.plot.isNotEmpty ?? false) ? info!.plot : widget.series.plot;

    // Next episode to resume = latest touched episode in this series.
    PlayItem? resume;
    int resumeIndex = 0;
    List<PlayItem> resumeList = const [];
    if (info != null) {
      WatchEntry? latest;
      for (final list in info.seasons.values) {
        for (final e in list) {
          final p = s.progressFor(_key(s, e));
          if (p != null && (latest == null || p.updatedMs > latest.updatedMs)) {
            latest = p;
            resumeList = _playlist(s, list);
            resumeIndex = list.indexOf(e);
          }
        }
      }
      if (latest != null) resume = resumeList[resumeIndex];
    }

    final header = Container(
      color: c.placeholder,
      padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 16, wide ? 40 : 20, 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        NetImage(widget.series.cover, width: wide ? 170 : 110, height: wide ? 255 : 165, radius: 14, icon: Icons.movie_outlined),
        SizedBox(width: wide ? 28 : 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.series.name, style: TextStyle(fontSize: wide ? 34 : 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final t in [
                if (info?.year.isNotEmpty ?? false) info!.year,
                if (info != null && info.seasons.isNotEmpty) '${info.seasons.length} مواسم',
                if (info?.genre.isNotEmpty ?? false) info!.genre,
                if ((info?.rating ?? widget.series.rating).isNotEmpty) '★ ${info?.rating.isNotEmpty == true ? info!.rating : widget.series.rating}',
              ])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(6)),
                  child: Text(t, style: TextStyle(fontSize: 13, color: c.muted)),
                ),
            ]),
            if (plot.isNotEmpty && wide) ...[
              const SizedBox(height: 10),
              Text(plot, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, height: 1.7)),
            ],
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (resume != null)
                PrimaryButton(
                  label: 'استكمال ${resume.subtitle}',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => PlayerScreen.open(context, resumeList, resumeIndex),
                )
              else if (eps.isNotEmpty)
                PrimaryButton(
                  label: 'تشغيل الحلقة الأولى',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => PlayerScreen.open(context, _playlist(s, eps), 0),
                ),
              FavButton(favKey: AppState.seriesKey(widget.series)),
            ]),
          ]),
        ),
      ]),
    );

    return Scaffold(
      appBar: AppBar(backgroundColor: c.placeholder, elevation: 0, scrolledUnderElevation: 0),
      body: ListView(children: [
        header,
        if (plot.isNotEmpty && !wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(plot, style: TextStyle(color: c.muted, height: 1.7)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 24, wide ? 40 : 20, 32),
          child: info == null
              ? (_error != null
                  ? EmptyState(icon: Icons.error_outline, text: _error!, action: SoftButton(label: 'إعادة المحاولة', onPressed: _load))
                  : const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  CategoryChips(
                    items: info.seasons.keys.map((k) => MapEntry('$k', 'الموسم $k')).toList(),
                    selected: '$_season',
                    onSelect: (k) => setState(() => _season = int.tryParse(k)),
                  ),
                  const SizedBox(height: 18),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: wide ? 280 : 220,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: eps.length,
                    itemBuilder: (_, i) {
                      final e = eps[i];
                      final p = s.progressFor(_key(s, e));
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => PlayerScreen.open(context, _playlist(s, eps), i),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Stack(fit: StackFit.expand, children: [
                              NetImage(e.image.isNotEmpty ? e.image : widget.series.cover, icon: Icons.play_circle_outline),
                              if (p != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: LinearProgressIndicator(value: p.fraction, minHeight: 4, color: c.accent, backgroundColor: c.line),
                                ),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: Text(
                                e.title.isNotEmpty && !e.title.contains(widget.series.name) ? e.title : 'الحلقة ${e.number}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            if (e.duration.isNotEmpty) Text(e.duration, style: TextStyle(color: c.muted, fontSize: 12)),
                          ]),
                        ]),
                      );
                    },
                  ),
                ]),
        ),
      ]),
    );
  }
}
