import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Persistence: settings in SharedPreferences, secrets in the OS keychain
/// (Keychain / Credential Manager) with a safe fallback when the keychain is
/// unavailable (e.g. unsigned macOS builds), library cache as JSON files.
class Store {
  late SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  bool _secureOk = true;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      await _secure.write(key: 'ra7al_probe', value: '1');
      _secureOk = (await _secure.read(key: 'ra7al_probe')) == '1';
    } catch (_) {
      _secureOk = false;
    }
  }

  // ---- secrets ----
  Future<void> writeSecret(String key, String value) async {
    if (_secureOk) {
      try {
        await _secure.write(key: key, value: value);
        return;
      } catch (_) {
        _secureOk = false;
      }
    }
    await _prefs.setString('sec_$key', _obfuscate(value));
  }

  Future<String> readSecret(String key) async {
    if (_secureOk) {
      try {
        final v = await _secure.read(key: key);
        if (v != null) return v;
      } catch (_) {
        _secureOk = false;
      }
    }
    final o = _prefs.getString('sec_$key');
    return o == null ? '' : _deobfuscate(o);
  }

  Future<void> deleteSecret(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
    await _prefs.remove('sec_$key');
  }

  static const _k = 'RA7AlTV-local-key';
  String _obfuscate(String s) {
    final b = utf8.encode(s);
    return base64.encode([for (var i = 0; i < b.length; i++) b[i] ^ _k.codeUnitAt(i % _k.length)]);
  }

  String _deobfuscate(String s) {
    try {
      final b = base64.decode(s);
      return utf8.decode([for (var i = 0; i < b.length; i++) b[i] ^ _k.codeUnitAt(i % _k.length)]);
    } catch (_) {
      return '';
    }
  }

  // ---- simple values ----
  String getString(String k, [String d = '']) => _prefs.getString(k) ?? d;
  Future<void> setString(String k, String v) => _prefs.setString(k, v);
  bool getBool(String k, [bool d = false]) => _prefs.getBool(k) ?? d;
  Future<void> setBool(String k, bool v) => _prefs.setBool(k, v);

  // ---- profiles ----
  Future<List<Profile>> loadProfiles() async {
    final raw = _prefs.getString('profiles');
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List).map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      for (final p in list) {
        p.password = await readSecret('pw_${p.id}');
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfiles(List<Profile> list) async {
    await _prefs.setString('profiles', jsonEncode(list.map((e) => e.toJson()).toList()));
    for (final p in list) {
      if (p.password.isNotEmpty) await writeSecret('pw_${p.id}', p.password);
    }
  }

  // ---- library cache ----
  Future<File> _cacheFile(String profileId) async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory('${dir.path}/cache');
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/lib_$profileId.json');
  }

  Future<Library?> loadLibrary(String profileId) async {
    try {
      final f = await _cacheFile(profileId);
      if (!await f.exists()) return null;
      return Library.decode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLibrary(String profileId, Library lib) async {
    try {
      final f = await _cacheFile(profileId);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(lib.encode(), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  Future<void> clearCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final d = Directory('${dir.path}/cache');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  // ---- favourites & progress ----
  Set<String> favorites(String profileId) => (_prefs.getStringList('fav_$profileId') ?? const []).toSet();
  Future<void> setFavorites(String profileId, Set<String> ids) =>
      _prefs.setStringList('fav_$profileId', ids.toList());

  List<WatchEntry> history(String profileId) {
    final raw = _prefs.getString('hist_$profileId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => WatchEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setHistory(String profileId, List<WatchEntry> list) =>
      _prefs.setString('hist_$profileId', jsonEncode(list.map((e) => e.toJson()).toList()));
}
