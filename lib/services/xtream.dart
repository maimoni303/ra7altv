import 'dart:convert';

import '../models.dart';
import 'net.dart';
import 'source.dart';

/// Xtream Codes `player_api.php` client.
class XtreamSource implements MediaSource {
  final Profile p;
  final Net net;
  late final String base = normalizeServer(p.server);

  XtreamSource(this.p) : net = Net(allowInsecure: p.allowInsecure);

  String _u(String s) => Uri.encodeComponent(s);
  String get _auth => 'username=${_u(p.username)}&password=${_u(p.password)}';
  String _api([String? action, String extra = '']) =>
      '$base/player_api.php?$_auth${action == null ? '' : '&action=$action'}$extra';

  String _seg(String s) => Uri.encodeComponent(s);
  String liveUrl(String id) => '$base/live/${_seg(p.username)}/${_seg(p.password)}/$id.${p.liveFormat}';
  String movieUrl(String id, String ext) =>
      '$base/movie/${_seg(p.username)}/${_seg(p.password)}/$id.${ext.isEmpty ? 'mp4' : ext}';
  String episodeUrl(String id, String ext) =>
      '$base/series/${_seg(p.username)}/${_seg(p.password)}/$id.${ext.isEmpty ? 'mp4' : ext}';

  @override
  Future<AccountInfo> verify() async {
    final j = await net.getJson(_api());
    if (j is! Map || j['user_info'] is! Map) {
      throw NetException('الخادم لا يدعم Xtream Codes أو الرابط غير صحيح');
    }
    final u = j['user_info'] as Map;
    if (asInt(u['auth']) != 1) throw NetException('بيانات الدخول غير صحيحة');
    final status = asStr(u['status']);
    final exp = asInt(u['exp_date']);
    return AccountInfo(
      status: status,
      expires: exp > 0 ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null,
      maxConnections: asInt(u['max_connections']),
    );
  }

  Future<List<Map>> _list(String action) async {
    try {
      final j = await net.getJson(_api(action));
      if (j is List) return j.whereType<Map>().toList();
      if (j is Map) return j.values.whereType<Map>().toList();
    } on NetException {
      rethrow;
    } catch (_) {}
    return const [];
  }

  List<Category> _cats(List<Map> raw) =>
      raw.map((m) => Category(asStr(m['category_id']), asStr(m['category_name']))).toList();

  @override
  Future<Library> load() async {
    final results = await Future.wait([
      _list('get_live_categories'),
      _list('get_live_streams'),
      _list('get_vod_categories'),
      _list('get_vod_streams'),
      _list('get_series_categories'),
      _list('get_series'),
    ]);
    final live = results[1].map((m) {
      final id = asStr(m['stream_id']);
      return LiveChannel(
        id: id,
        name: asStr(m['name']).trim(),
        logo: asStr(m['stream_icon']),
        categoryId: asStr(m['category_id']),
        url: liveUrl(id),
        epgId: asStr(m['epg_channel_id']),
        num: asInt(m['num']),
        archive: asInt(m['tv_archive']) == 1,
      );
    }).toList();
    final vod = results[3].map((m) {
      final id = asStr(m['stream_id']);
      return VodItem(
        id: id,
        name: asStr(m['name']).trim(),
        poster: asStr(m['stream_icon']),
        categoryId: asStr(m['category_id']),
        url: movieUrl(id, asStr(m['container_extension'])),
        rating: asStr(m['rating']),
        added: asInt(m['added']),
      );
    }).toList();
    final series = results[5].map((m) => SeriesItem(
          id: asStr(m['series_id']),
          name: asStr(m['name']).trim(),
          cover: asStr(m['cover']),
          categoryId: asStr(m['category_id']),
          plot: asStr(m['plot']),
          rating: asStr(m['rating']),
          added: asInt(m['last_modified']),
        )).toList();
    return Library(
      liveCats: _cats(results[0]),
      live: live,
      vodCats: _cats(results[2]),
      vod: vod,
      seriesCats: _cats(results[4]),
      series: series,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<SeriesInfo> seriesInfo(SeriesItem s) async {
    final j = await net.getJson(_api('get_series_info', '&series_id=${s.id}'));
    if (j is! Map) return const SeriesInfo();
    final info = j['info'] is Map ? j['info'] as Map : const {};
    final seasons = <int, List<Episode>>{};
    final eps = j['episodes'];
    void addEp(dynamic e, int fallbackSeason) {
      if (e is! Map) return;
      final id = asStr(e['id']);
      final season = asInt(e['season']) == 0 ? fallbackSeason : asInt(e['season']);
      final einfo = e['info'] is Map ? e['info'] as Map : const {};
      seasons.putIfAbsent(season, () => []).add(Episode(
            id: id,
            title: asStr(e['title']),
            url: episodeUrl(id, asStr(e['container_extension'])),
            season: season,
            number: asInt(e['episode_num']),
            image: asStr(einfo['movie_image']),
            duration: asStr(einfo['duration']),
          ));
    }

    if (eps is Map) {
      eps.forEach((k, v) {
        if (v is List) {
          for (final e in v) {
            addEp(e, asInt(k));
          }
        }
      });
    } else if (eps is List) {
      for (final group in eps) {
        if (group is List) {
          for (final e in group) {
            addEp(e, 1);
          }
        }
      }
    }
    for (final l in seasons.values) {
      l.sort((a, b) => a.number.compareTo(b.number));
    }
    return SeriesInfo(
      plot: asStr(info['plot']),
      cover: asStr(info['cover']),
      year: asStr(info['releaseDate']).isNotEmpty ? asStr(info['releaseDate']) : asStr(info['year']),
      genre: asStr(info['genre']),
      rating: asStr(info['rating']),
      seasons: Map.fromEntries(seasons.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
    );
  }

  @override
  Future<List<EpgEntry>> epg(LiveChannel ch) async {
    try {
      final j = await net.getJson(_api('get_short_epg', '&stream_id=${ch.id}&limit=12'));
      final list = j is Map ? j['epg_listings'] : null;
      if (list is! List) return const [];
      String dec(dynamic v) {
        final s = asStr(v);
        try {
          return utf8.decode(base64.decode(s), allowMalformed: true);
        } catch (_) {
          return s;
        }
      }

      DateTime ts(dynamic secs, dynamic text) {
        final n = asInt(secs);
        if (n > 0) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        return DateTime.tryParse(asStr(text)) ?? DateTime.now();
      }

      return list.whereType<Map>().map((m) => EpgEntry(
            dec(m['title']),
            dec(m['description']),
            ts(m['start_timestamp'], m['start']),
            ts(m['stop_timestamp'], m['end']),
          )).where((e) => e.end.isAfter(DateTime.now())).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
    } catch (_) {
      return const [];
    }
  }
}
