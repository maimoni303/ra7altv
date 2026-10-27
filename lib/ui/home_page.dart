import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'player_screen.dart';
import 'shell.dart';
import 'vod_page.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 36.0 : 20.0;
    final cont = s.continueWatching;
    final favs = s.favoriteChannels;

    return RefreshIndicator(
      onRefresh: () => s.refresh(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, wide ? 28 : 16, pad, 32),
        children: [
          Row(children: [
            if (!wide) ...[const BrandTitle(), const Spacer()],
            if (wide)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Shell.go(context, 4),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: c.input,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.search_rounded, color: c.muted, size: 20),
                      const SizedBox(width: 10),
                      Text('ابحث في القنوات والأفلام والمسلسلات', style: TextStyle(color: c.faint)),
                    ]),
                  ),
                ),
              ),
            if (wide) const SizedBox(width: 12),
            if (!wide)
              IconButton.filledTonal(
                tooltip: 'بحث',
                onPressed: () => Shell.go(context, 4),
                icon: const Icon(Icons.search_rounded),
              ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: Theme.of(context).brightness == Brightness.dark ? 'الثيم الفاتح' : 'الثيم الداكن',
              onPressed: () => s.toggleTheme(Theme.of(context).brightness),
              icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
          ]),
          if (s.loading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(minHeight: 3, color: c.accent, backgroundColor: c.line),
          ],
          if (s.error != null) ...[
            const SizedBox(height: 12),
            _Banner(text: s.error!, onRetry: () => s.refresh()),
          ],
          const SizedBox(height: 24),
          if (s.library.isEmpty && !s.loading)
            EmptyState(
              icon: Icons.cloud_off_rounded,
              text: 'لم يتم تحميل أي محتوى بعد',
              action: PrimaryButton(label: 'إعادة المحاولة', onPressed: () => s.refresh()),
            ),
          if (cont.isNotEmpty) ...[
            _Hero(entry: cont.first),
            const SizedBox(height: 28),
          ],
          if (cont.length > 1) ...[
            const SectionTitle('تابع المشاهدة'),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cont.length - 1,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _ResumeCard(entry: cont[i + 1]),
              ),
            ),
            const SizedBox(height: 28),
          ],
          if (favs.isNotEmpty) ...[
            SectionTitle('قنواتك المفضلة', action: 'الكل', onAction: () => Shell.go(context, 1)),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _ChannelTile(list: favs, index: i),
              ),
            ),
            const SizedBox(height: 28),
          ],
          if (s.recentVod.isNotEmpty) ...[
            SectionTitle('أفلام أضيفت مؤخراً', action: 'عرض الكل', onAction: () => Shell.go(context, 2)),
            PosterRow(items: s.recentVod.map(PosterData.fromVod).toList()),
            const SizedBox(height: 28),
          ],
          if (s.recentSeries.isNotEmpty) ...[
            SectionTitle('مسلسلات حديثة', action: 'عرض الكل', onAction: () => Shell.go(context, 3)),
            PosterRow(items: s.recentSeries.map(PosterData.fromSeries).toList()),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Banner({required this.text, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: c.live, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('تعذّر التحديث: $text', style: TextStyle(color: c.muted, fontSize: 13))),
        TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ]),
    );
  }
}

PlayItem playItemFromEntry(WatchEntry e) => PlayItem(
      key: e.key,
      title: e.title,
      subtitle: e.subtitle,
      url: e.url,
      image: e.image,
      kind: e.kind,
      resumeMs: e.positionMs,
    );

class _Hero extends StatelessWidget {
  final WatchEntry entry;
  const _Hero({required this.entry});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: wide ? 280 : 210,
        color: c.placeholder,
        child: Stack(fit: StackFit.expand, children: [
          if (entry.image.isNotEmpty) NetImage(entry.image, radius: 0),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.1)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 28 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('تابع المشاهدة', style: TextStyle(color: Ra7al.dark.accent, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: wide ? 30 : 22, fontWeight: FontWeight.w700)),
              if (entry.subtitle.isNotEmpty)
                Text(entry.subtitle, style: const TextStyle(color: Color(0xFFC8D0EA), fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(
                width: wide ? 420 : double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: entry.fraction,
                    minHeight: 4,
                    color: Ra7al.dark.accent,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'استكمال',
                icon: Icons.play_arrow_rounded,
                onPressed: () => PlayerScreen.open(context, [playItemFromEntry(entry)], 0),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final WatchEntry entry;
  const _ResumeCard({required this.entry});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => PlayerScreen.open(context, [playItemFromEntry(entry)], 0),
      child: SizedBox(
        width: 200,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            NetImage(entry.image, width: 200, height: 112, icon: Icons.movie_outlined),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(value: entry.fraction, minHeight: 4, color: c.accent, backgroundColor: c.line),
            ),
          ]),
          const SizedBox(height: 6),
          Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final List<LiveChannel> list;
  final int index;
  const _ChannelTile({required this.list, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ch = list[index];
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => PlayerScreen.open(context, list.map(PlayItem.fromChannel).toList(), index),
      child: SizedBox(
        width: 84,
        child: Column(children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(18)),
            child: NetImage(ch.logo, fit: BoxFit.contain, radius: 6),
          ),
          const SizedBox(height: 6),
          Text(ch.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
        ]),
      ),
    );
  }
}
