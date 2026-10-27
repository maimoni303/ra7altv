import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Many IPTV panels only answer player-like user agents.
const kUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

class NetException implements Exception {
  final String message;
  NetException(this.message);
  @override
  String toString() => message;
}

/// HTTP helper built on dart:io so self-signed / expired certificates can be
/// accepted per profile (common with IPTV providers), with timeouts and retries.
class Net {
  final bool allowInsecure;
  final Duration timeout;
  final int retries;

  Net({this.allowInsecure = true, this.timeout = const Duration(seconds: 25), this.retries = 2});

  HttpClient _client() {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = kUserAgent
      ..autoUncompress = true;
    if (allowInsecure) {
      c.badCertificateCallback = (cert, host, port) => true;
    }
    return c;
  }

  Future<List<int>> getBytes(String url) async {
    Object? last;
    for (var attempt = 0; attempt <= retries; attempt++) {
      final client = _client();
      try {
        final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
        req.followRedirects = true;
        req.maxRedirects = 8;
        req.headers.set(HttpHeaders.acceptHeader, '*/*');
        final res = await req.close().timeout(timeout);
        if (res.statusCode >= 400) {
          await res.drain<void>();
          throw NetException(_statusMessage(res.statusCode));
        }
        final out = <int>[];
        await for (final chunk in res.timeout(const Duration(seconds: 60))) {
          out.addAll(chunk);
        }
        return out;
      } on NetException catch (e) {
        last = e;
        // 401/403/404 won't improve with a retry.
        if (e.message.contains('401') || e.message.contains('403') || e.message.contains('404')) rethrow;
      } on TimeoutException {
        last = NetException('انتهت مهلة الاتصال بالخادم');
      } on SocketException {
        last = NetException('تعذّر الوصول إلى الخادم، تحقق من الرابط والإنترنت');
      } on HandshakeException {
        last = NetException('مشكلة في شهادة الأمان للخادم. فعّل خيار قبول الشهادات غير الموثوقة');
      } on FormatException {
        throw NetException('الرابط غير صالح');
      } catch (e) {
        last = e;
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
    }
    throw last is NetException ? last : NetException('خطأ في الاتصال: $last');
  }

  Future<String> getText(String url) async {
    var bytes = await getBytes(url);
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      bytes = gzip.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<dynamic> getJson(String url) async {
    final text = await getText(url);
    try {
      return jsonDecode(text);
    } catch (_) {
      throw NetException('استجابة غير متوقعة من الخادم');
    }
  }

  static String _statusMessage(int code) {
    switch (code) {
      case 401:
      case 403:
        return 'بيانات الدخول غير صحيحة أو الاشتراك منتهي ($code)';
      case 404:
        return 'الرابط غير موجود على الخادم (404)';
      default:
        return 'الخادم أعاد خطأ ($code)';
    }
  }
}

/// Normalises a user-typed server address: adds a scheme, drops trailing slashes
/// and any pasted `player_api.php` / `get.php` suffix.
String normalizeServer(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
  final uri = Uri.tryParse(s);
  if (uri == null) return s;
  var path = uri.path;
  for (final tail in ['/player_api.php', '/get.php', '/panel_api.php']) {
    if (path.endsWith(tail)) path = path.substring(0, path.length - tail.length);
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}
