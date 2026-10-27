import 'dart:convert';

String asStr(dynamic v) => v == null ? '' : v.toString();
int asInt(dynamic v) => v is int ? v : int.tryParse(asStr(v)) ?? 0;

enum SourceType { xtream, m3u }

class Profile {
  final String id;
  String name;
  SourceType type;
  String server; // xtream base URL or M3U URL
  String username;
  String password; // never persisted in plain prefs (see Store)
  String epgUrl;
  bool allowInsecure;
  String liveFormat; // 'ts' | 'm3u8'

  Profile({
    required this.id,
    required this.name,
    required this.type,
    required this.server,
    this.username = '',
    this.password = '',
    this.epgUrl = '',
    this.allowInsecure = true,
    this.liveFormat = 'ts',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'server': server,
        'username': username,
        'epgUrl': epgUrl,
        'allowInsecure': allowInsecure,
        'liveFormat': liveFormat,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: asStr(j['id']),
        name: asStr(j['name']),
        type: j['type'] == 'm3u' ? SourceType.m3u : SourceType.xtream,
        server: asStr(j['server']),
        username: asStr(j['username']),
        epgUrl: asStr(j['epgUrl']),
        allowInsecure: j['allowInsecure'] != false,
        liveFormat: asStr(j['liveFormat']).isEmpty ? 'ts' : asStr(j['liveFormat']),
      );
}

class Category {
  final String id, name;
  const Category(this.id, this.name);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Category.fromJson(Map<String, dynamic> j) => Category(asStr(j['id']), asStr(j['name']));
}

class LiveChannel {
  final String id, name, logo, categoryId, url, epgId;
  final int num;
  final bool archive;
  const LiveChannel({
    required this.id,
    required this.name,
    required this.logo,
    required this.categoryId,
    required this.url,
    this.epgId = '',
    this.num = 0,
    this.archive = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'logo': logo, 'cat': categoryId, 'url': url,
        'epg': epgId, 'num': num, 'arc': archive,
      };
  factory LiveChannel.fromJson(Map<String, dynamic> j) => LiveChannel(
        id: asStr(j['id']), name: asStr(j['name']), logo: asStr(j['logo']),
        categoryId: asStr(j['cat']), url: asStr(j['url']), epgId: asStr(j['epg']),
        num: asInt(j['num']), archive: j['arc'] == true,
      );
}

class VodItem {
  final String id, name, poster, categoryId, url, rating;
  final int added;
  const VodItem({
    required this.id,
    required this.name,
    required this.poster,
    required this.categoryId,
    required this.url,
    this.rating = '',
    this.added = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'poster': poster, 'cat': categoryId, 'url': url,
        'rating': rating, 'added': added,
      };
  factory VodItem.fromJson(Map<String, dynamic> j) => VodItem(
        id: asStr(j['id']), name: asStr(j['name']), poster: asStr(j['poster']),
        categoryId: asStr(j['cat']), url: asStr(j['url']), rating: asStr(j['rating']),
        added: asInt(j['added']),
      );
}

class SeriesItem {
  final String id, name, cover, categoryId, plot, rating;
  final int added;
  const SeriesItem({
    required this.id,
    required this.name,
    required this.cover,
    required this.categoryId,
    this.plot = '',
    this.rating = '',
    this.added = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cover': cover, 'cat': categoryId, 'plot': plot,
        'rating': rating, 'added': added,
      };
  factory SeriesItem.fromJson(Map<String, dynamic> j) => SeriesItem(
        id: asStr(j['id']), name: asStr(j['name']), cover: asStr(j['cover']),
        categoryId: asStr(j['cat']), plot: asStr(j['plot']), rating: asStr(j['rating']),
        added: asInt(j['added']),
      );
}

class Episode {
  final String id, title, url, image;
  final int season, number;
  final String duration;
  const Episode({
    required this.id,
    required this.title,
    required this.url,
    required this.season,
    required this.number,
    this.image = '',
    this.duration = '',
  });
}

class SeriesInfo {
  final String plot, cover, year, genre, rating;
  final Map<int, List<Episode>> seasons;
  const SeriesInfo({
    this.plot = '',
    this.cover = '',
    this.year = '',
    this.genre = '',
    this.rating = '',
    this.seasons = const {},
  });
}

class EpgEntry {
  final String title, desc;
  final DateTime start, end;
  const EpgEntry(this.title, this.desc, this.start, this.end);
  bool get isNow {
    final n = DateTime.now();
    return !start.isAfter(n) && end.isAfter(n);
  }

  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (DateTime.now().difference(start).inSeconds / total).clamp(0.0, 1.0);
  }
}

class Library {
  final List<Category> liveCats, vodCats, seriesCats;
  final List<LiveChannel> live;
  final List<VodItem> vod;
  final List<SeriesItem> series;
  final DateTime fetchedAt;

  const Library({
    this.liveCats = const [],
    this.vodCats = const [],
    this.seriesCats = const [],
    this.live = const [],
    this.vod = const [],
    this.series = const [],
    required this.fetchedAt,
  });

  static Library empty() => Library(fetchedAt: DateTime.fromMillisecondsSinceEpoch(0));
  bool get isEmpty => live.isEmpty && vod.isEmpty && series.isEmpty;

  String encode() => jsonEncode({
        'lc': liveCats.map((e) => e.toJson()).toList(),
        'vc': vodCats.map((e) => e.toJson()).toList(),
        'sc': seriesCats.map((e) => e.toJson()).toList(),
        'l': live.map((e) => e.toJson()).toList(),
        'v': vod.map((e) => e.toJson()).toList(),
        's': series.map((e) => e.toJson()).toList(),
        't': fetchedAt.millisecondsSinceEpoch,
      });

  static Library decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    return Library(
      liveCats: list('lc', Category.fromJson),
      vodCats: list('vc', Category.fromJson),
      seriesCats: list('sc', Category.fromJson),
      live: list('l', LiveChannel.fromJson),
      vod: list('v', VodItem.fromJson),
      series: list('s', SeriesItem.fromJson),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(asInt(j['t'])),
    );
  }
}

/// A resumable item for "continue watching".
class WatchEntry {
  final String key, title, subtitle, url, image, kind; // kind: movie | episode
  final int positionMs, durationMs, updatedMs;
  const WatchEntry({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.image,
    required this.kind,
    required this.positionMs,
    required this.durationMs,
    required this.updatedMs,
  });
  double get fraction => durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);
  bool get finished => durationMs > 0 && positionMs > durationMs * 0.95;
  Map<String, dynamic> toJson() => {
        'k': key, 't': title, 's': subtitle, 'u': url, 'i': image, 'kind': kind,
        'p': positionMs, 'd': durationMs, 'at': updatedMs,
      };
  factory WatchEntry.fromJson(Map<String, dynamic> j) => WatchEntry(
        key: asStr(j['k']), title: asStr(j['t']), subtitle: asStr(j['s']), url: asStr(j['u']),
        image: asStr(j['i']), kind: asStr(j['kind']), positionMs: asInt(j['p']),
        durationMs: asInt(j['d']), updatedMs: asInt(j['at']),
      );
}
