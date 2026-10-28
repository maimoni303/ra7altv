import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'player_screen.dart';
import 'vod_page.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 36.0 : 20.0;
    final q = _q.toLowerCase();
    final List<LiveChannel> live =
        q.length < 2 ? const [] : s.library.live.where((e) => e.name.toLowerCase().contains(q)).take(40).toList();
    final List<VodItem> vod =
        q.length < 2 ? const [] : s.library.vod.where((e) => e.name.toLowerCase().contains(q)).take(40).toList();
    final List<SeriesItem> series =
        q.length < 2 ? const [] : s.library.series.where((e) => e.name.toLowerCase().contains(q)).take(40).toList();

    return ListView(padding: EdgeInsets.fromLTRB(pad, wide ? 28 : 16, pad, 32), children: [
      Padding(
        padding: EdgeInsetsDirectional.only(end: wide ? 150 : 120),
        child: TextField(
        autofocus: true,
        onChanged: (v) => setState(() => _q = v.trim()),
        decoration: fieldDecoration(context, hint: 'ابحث في القنوات والأفلام والمسلسلات', prefix: const Icon(Icons.search_rounded)),
      )),
      const SizedBox(height: 24),
      if (q.length < 2)
        EmptyState(icon: Icons.search_rounded, text: 'اكتب حرفين على الأقل للبحث')
      else if (live.isEmpty && vod.isEmpty && series.isEmpty)
        const EmptyState(icon: Icons.search_off_rounded, text: 'لا توجد نتائج'),
      if (live.isNotEmpty) ...[
        SectionTitle('القنوات (${live.length})'),
        ...List.generate(live.length, (i) {
          final ch = live[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: NetImage(ch.logo, width: 44, height: 44, fit: BoxFit.contain),
            title: Text(ch.name),
            trailing: Icon(Icons.play_circle_outline_rounded, color: c.accent),
            onTap: () => PlayerScreen.open(context, live.map((e) => PlayItem.fromChannel(e)).toList(), i),
          );
        }),
        const SizedBox(height: 24),
      ],
      if (vod.isNotEmpty) ...[
        SectionTitle('الأفلام (${vod.length})'),
        PosterRow(items: vod.map((e) => PosterData.fromVod(e)).toList()),
        const SizedBox(height: 24),
      ],
      if (series.isNotEmpty) ...[
        SectionTitle('المسلسلات (${series.length})'),
        PosterRow(items: series.map((e) => PosterData.fromSeries(e)).toList()),
      ],
    ]);
  }
}
