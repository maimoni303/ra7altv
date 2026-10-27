import '../models.dart';
import 'm3u.dart';
import 'xtream.dart';

class AccountInfo {
  final String status;
  final DateTime? expires;
  final int maxConnections;
  const AccountInfo({this.status = '', this.expires, this.maxConnections = 0});
}

/// Common interface for every kind of provider.
abstract class MediaSource {
  Future<AccountInfo> verify();
  Future<Library> load();
  Future<SeriesInfo> seriesInfo(SeriesItem s);
  Future<List<EpgEntry>> epg(LiveChannel ch);

  static MediaSource of(Profile p) => p.type == SourceType.xtream ? XtreamSource(p) : M3uSource(p);
}
