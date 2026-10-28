import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'player_screen.dart';
import 'series_details.dart';
import 'widgets.dart';

class PosterData {
  final String title, image, rating;
  final VodItem? vod;
  final SeriesItem? series;
  const PosterData(this.title, this.image, this.rating, {this.vod, this.series});
  static PosterData fromVod(VodItem v) => PosterData(v.name, v.poster, v.rating, vod: v);
  static PosterData fromSeries(SeriesItem s) => PosterData(s.name, s.cover, s.rating, series: s);
}

void openPoster(BuildContext context, PosterData d) {
  if (d.series != null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesDetails(series: d.series!)));
  } else if (d.vod != null) {
    showMovieSheet(context, d.vod!);
  }
}

void showMovieSheet(BuildContext context, VodItem v) {
  final s = context.read<AppState>();
  final key = 'movie_${s.active?.id}_${v.id}';
  final prog = s.progressFor(key);
  final c = context.c;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.card,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NetImage(v.poster, width: 110, height: 165, icon: Icons.movie_outlined),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (v.rating.isNotEmpty && v.rating != '0')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('★ ${v.rating}', style: TextStyle(color: c.muted)),
              ),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, children: [
              PrimaryButton(
                label: prog != null && !prog.finished ? 'استكمال' : 'تشغيل',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  PlayerScreen.open(context, [PlayItem.fromVod(v, key, resumeMs: prog?.finished == false ? prog!.positionMs : 0)], 0);
                },
              ),
              FavButton(favKey: AppState.vodKey(v)),
              if (prog != null && !prog.finished)
                SoftButton(
                  label: 'من البداية',
                  icon: Icons.replay_rounded,
                  onPressed: () {
                    Navigator.pop(ctx);
                    PlayerScreen.open(context, [PlayItem.fromVod(v, key)], 0);
                  },
                ),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

class PosterCard extends StatelessWidget {
  final PosterData d;
  final double width;
  const PosterCard({super.key, required this.d, this.width = 140});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final key = d.vod != null ? AppState.vodKey(d.vod!) : d.series != null ? AppState.seriesKey(d.series!) : '';
    final fav = key.isNotEmpty && s.isFav(key);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openPoster(context, d),
      onLongPress: key.isEmpty ? null : () => s.toggleFav(key),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(d.image, radius: 12, icon: Icons.movie_outlined),
              if (fav)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(gradient: context.brandGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_rounded, size: 14, color: Colors.white),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class PosterRow extends StatelessWidget {
  final List<PosterData> items;
  const PosterRow({super.key, required this.items});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, i) => PosterCard(d: items[i]),
        ),
      );
}

class VodPage extends StatefulWidget {
  final bool series;
  const VodPage({super.key, required this.series});
  @override
  State<VodPage> createState() => _VodPageState();
}

class _VodPageState extends State<VodPage> {
  String _cat = '*';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 36.0 : 20.0;
    final cats = widget.series ? s.library.seriesCats : s.library.vodCats;
    final items = widget.series
        ? s.seriesIn(_cat).map(PosterData.fromSeries).toList()
        : s.vodIn(_cat).map(PosterData.fromVod).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 28 : 16, pad, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.series ? 'المسلسلات' : 'الأفلام', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        CategoryChips(
          items: [const MapEntry('*', 'الكل'), const MapEntry('fav', 'المفضلة'), ...cats.map((c) => MapEntry(c.id, c.name))],
          selected: _cat,
          onSelect: (id) => setState(() => _cat = id),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: items.isEmpty
              ? EmptyState(icon: Icons.movie_filter_outlined, text: s.loading ? 'جارٍ التحميل…' : 'لا يوجد محتوى في هذا التصنيف')
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: wide ? 170 : 130,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.56,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => PosterCard(d: items[i], width: double.infinity),
                ),
        ),
      ]),
    );
  }
}


/// Heart toggle used on movie and series pages.
class FavButton extends StatelessWidget {
  final String favKey;
  const FavButton({super.key, required this.favKey});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final on = s.isFav(favKey);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: on ? context.brandGradient : null,
        color: on ? null : c.active,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        tooltip: on ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
        onPressed: () {
          s.toggleFav(favKey);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(on ? 'أُزيل من المفضلة' : 'أُضيف إلى المفضلة'),
          ));
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (ch, a) => ScaleTransition(scale: a, child: ch),
          child: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(on), color: on ? Colors.white : c.text),
        ),
      ),
    );
  }
}
