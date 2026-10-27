import '../models.dart';
import 'net.dart';
import 'source.dart';
import 'xmltv.dart';

class M3uEntry {
  final String name, url, logo, group, tvgId;
  const M3uEntry(this.name, this.url, this.logo, this.group, this.tvgId);
}

final _attr = RegExp(r'([\w-]+)="([^"]*)"');

/// Parses an extended M3U playlist. Tolerates CRLF, BOM, missing headers.
List<M3uEntry> parseM3u(String text, {void Function(String epgUrl)? onEpg}) {
  final out = <M3uEntry>[];
  String? pendingInfo;
  String? pendingGroup;
  for (var raw in text.split('\n')) {
    final line = raw.trim().replaceAll('﻿', '');
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTM3U')) {
      final m = RegExp(r'(?:url-tvg|x-tvg-url)="([^"]+)"').firstMatch(line);
      if (m != null && onEpg != null) onEpg(m.group(1)!.split(',').first.trim());
      continue;
    }
    if (line.startsWith('#EXTINF')) {
      pendingInfo = line;
      continue;
    }
    if (line.startsWith('#EXTGRP:')) {
      pendingGroup = line.substring(8).trim();
      continue;
    }
    if (line.startsWith('#')) continue;
    final info = pendingInfo ?? '';
    final attrs = <String, String>{};
    for (final m in _attr.allMatches(info)) {
      attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
    }
    final comma = info.lastIndexOf(',');
    var name = comma >= 0 ? info.substring(comma + 1).trim() : '';
    if (name.isEmpty) name = attrs['tvg-name'] ?? line.split('/').last;
    out.add(M3uEntry(
      name,
      line,
      attrs['tvg-logo'] ?? '',
      attrs['group-title'] ?? pendingGroup ?? 'عام',
      attrs['tvg-id'] ?? '',
    ));
    pendingInfo = null;
    pendingGroup = null;
  }
  return out;
}

class M3uSource implements MediaSource {
  final Profile p;
  final Net net;
  Xmltv? _guide;
  String _epgFromPlaylist = '';

  M3uSource(this.p) : net = Net(allowInsecure: p.allowInsecure);

  @override
  Future<AccountInfo> verify() async {
    final text = await net.getText(p.server.trim());
    if (!text.contains('#EXTINF') && !text.contains('#EXTM3U')) {
      throw NetException('الملف ليس قائمة M3U صالحة');
    }
    return const AccountInfo(status: 'Active');
  }

  @override
  Future<Library> load() async {
    final text = await net.getText(p.server.trim());
    final entries = parseM3u(text, onEpg: (u) => _epgFromPlaylist = u);
    final liveCats = <String, Category>{};
    final vodCats = <String, Category>{};
    final live = <LiveChannel>[];
    final vod = <VodItem>[];
    var i = 0;
    for (final e in entries) {
      i++;
      final lower = e.url.toLowerCase();
      final isVod = lower.contains('/movie/') ||
          lower.contains('/series/') ||
          RegExp(r'\.(mp4|mkv|avi|mov|m4v)(\?|$)').hasMatch(lower);
      final catId = e.group.isEmpty ? 'عام' : e.group;
      if (isVod) {
        vodCats.putIfAbsent(catId, () => Category(catId, catId));
        vod.add(VodItem(id: 'm$i', name: e.name, poster: e.logo, categoryId: catId, url: e.url, added: i));
      } else {
        liveCats.putIfAbsent(catId, () => Category(catId, catId));
        live.add(LiveChannel(
          id: 'c$i',
          name: e.name,
          logo: e.logo,
          categoryId: catId,
          url: e.url,
          epgId: e.tvgId,
          num: live.length + 1,
        ));
      }
    }
    return Library(
      liveCats: liveCats.values.toList(),
      live: live,
      vodCats: vodCats.values.toList(),
      vod: vod,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<SeriesInfo> seriesInfo(SeriesItem s) async => const SeriesInfo();

  @override
  Future<List<EpgEntry>> epg(LiveChannel ch) async {
    final url = p.epgUrl.isNotEmpty ? p.epgUrl : _epgFromPlaylist;
    if (url.isEmpty || ch.epgId.isEmpty) return const [];
    try {
      _guide ??= await Xmltv.load(net, url);
      return _guide!.forChannel(ch.epgId);
    } catch (_) {
      return const [];
    }
  }
}
