import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// One-time activation code.
///
/// The code itself is NEVER in the source. At build time CI injects a
/// PBKDF2-SHA256 hash + salt (from the repository secret
/// `RA7AL_ACTIVATION_CODE`) via --dart-define. Builds without it need no code.
class Activation {
  static const hashHex = String.fromEnvironment('ACT_HASH');
  static const saltHex = String.fromEnvironment('ACT_SALT');
  static const iterations = 120000;

  static bool get required => hashHex.isNotEmpty && saltHex.isNotEmpty;

  /// Stored after success; tied to the hash so a new code re-locks old installs.
  static String get token => required ? 'act_${hashHex.substring(0, 16)}' : 'act_none';

  static Future<bool> verify(String code) async {
    if (!required) return true;
    final salt = _hex(saltHex);
    final expected = hashHex.toLowerCase();
    final input = normalize(code);
    final got = await Isolate.run(() => _pbkdf2(utf8.encode(input), salt, iterations, 32));
    final gotHex = got.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    // constant-time compare
    if (gotHex.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < gotHex.length; i++) {
      diff |= gotHex.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Arabic/Persian keyboards type ٠-٩ / ۰-۹; treat them as 0-9 and drop
  /// invisible direction marks so the same code always matches.
  static String normalize(String s) {
    final b = StringBuffer();
    for (final r in s.trim().runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + r - 0x06F0);
      } else if (r == 0x200B || r == 0x200E || r == 0x200F || r == 0x061C || r == 0xFEFF) {
        continue;
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static Uint8List _hex(String s) {
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static List<int> _pbkdf2(List<int> password, List<int> salt, int iters, int len) {
    final hmac = Hmac(sha256, password);
    final out = <int>[];
    var block = 1;
    while (out.length < len) {
      final s = [...salt, (block >> 24) & 255, (block >> 16) & 255, (block >> 8) & 255, block & 255];
      var u = hmac.convert(s).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iters; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.addAll(t);
      block++;
    }
    return out.sublist(0, len);
  }
}
