import 'package:xml/xml_events.dart';

import '../models.dart';
import 'net.dart';

/// Streaming XMLTV parser that keeps only programmes from 2 h ago to 24 h ahead,
/// so large guides stay light on memory.
class Xmltv {
  final Map<String, List<EpgEntry>> byChannel;
  Xmltv(this.byChannel);

  List<EpgEntry> forChannel(String id) {
    final now = DateTime.now();
    return (byChannel[id] ?? const []).where((e) => e.end.isAfter(now)).toList();
  }

  static Future<Xmltv> load(Net net, String url) async {
    final text = await net.getText(url);
    return Xmltv(parse(text));
  }

  static DateTime? parseTime(String s) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?').firstMatch(s.trim());
    if (m == null) return null;
    final utc = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );
    final tz = m.group(7);
    if (tz == null) return utc.toLocal();
    final sign = tz.startsWith('-') ? -1 : 1;
    final offset = Duration(hours: int.parse(tz.substring(1, 3)), minutes: int.parse(tz.substring(3, 5)));
    return utc.subtract(offset * sign).toLocal();
  }

  static Map<String, List<EpgEntry>> parse(String text) {
    final from = DateTime.now().subtract(const Duration(hours: 2));
    final to = DateTime.now().add(const Duration(hours: 24));
    final map = <String, List<EpgEntry>>{};
    String? channel;
    DateTime? start, stop;
    String? field;
    var title = StringBuffer(), desc = StringBuffer();

    for (final ev in parseEvents(text)) {
      if (ev is XmlStartElementEvent) {
        if (ev.name == 'programme') {
          channel = null;
          start = stop = null;
          title = StringBuffer();
          desc = StringBuffer();
          for (final a in ev.attributes) {
            if (a.name == 'channel') channel = a.value;
            if (a.name == 'start') start = parseTime(a.value);
            if (a.name == 'stop') stop = parseTime(a.value);
          }
          if (ev.isSelfClosing) channel = null;
        } else if (channel != null && (ev.name == 'title' || ev.name == 'desc')) {
          field = ev.name;
        }
      } else if (ev is XmlTextEvent || ev is XmlCDATAEvent) {
        final value = ev is XmlTextEvent ? ev.value : (ev as XmlCDATAEvent).value;
        if (field == 'title' && title.isEmpty) title.write(value);
        if (field == 'desc' && desc.isEmpty) desc.write(value);
      } else if (ev is XmlEndElementEvent) {
        if (ev.name == 'title' || ev.name == 'desc') {
          field = null;
        } else if (ev.name == 'programme') {
          final s = start, e = stop, ch = channel;
          if (ch != null && s != null && e != null && e.isAfter(from) && s.isBefore(to)) {
            map.putIfAbsent(ch, () => []).add(EpgEntry(title.toString().trim(), desc.toString().trim(), s, e));
          }
          channel = null;
        }
      }
    }
    for (final l in map.values) {
      l.sort((a, b) => a.start.compareTo(b.start));
    }
    return map;
  }
}
