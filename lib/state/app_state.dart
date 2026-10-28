import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/activation.dart';
import '../services/source.dart';
import '../services/store.dart';

class AppState extends ChangeNotifier {
  final Store store;
  AppState(this.store);

  bool ready = false;
  bool activated = false;
  ThemeMode themeMode = ThemeMode.dark;

  List<Profile> profiles = [];
  Profile? active;
  MediaSource? source;
  Library library = Library.empty();
  bool loading = false;
  String? error;
  AccountInfo? account;

  Set<String> favorites = {};
  List<WatchEntry> history = [];

  Future<void> init() async {
    await store.init();
    final t = store.getString('theme', 'dark');
    themeMode = t == 'light' ? ThemeMode.light : t == 'system' ? ThemeMode.system : ThemeMode.dark;
    activated = !Activation.required || store.getBool(Activation.token);
    profiles = await store.loadProfiles();
    final lastId = store.getString('active');
    if (profiles.isNotEmpty) {
      final p = profiles.firstWhere((e) => e.id == lastId, orElse: () => profiles.first);
      await _select(p, refresh: false);
    }
    ready = true;
    notifyListeners();
    if (active != null) unawaited(refresh(silent: !library.isEmpty));
  }

  Future<bool> activate(String code) async {
    final ok = await Activation.verify(code);
    if (ok) {
      activated = true;
      await store.setBool(Activation.token, true);
      notifyListeners();
    }
    return ok;
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    store.setString('theme', m == ThemeMode.light ? 'light' : m == ThemeMode.system ? 'system' : 'dark');
    notifyListeners();
  }

  void toggleTheme(Brightness current) =>
      setTheme(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  // ---- profiles ----
  Future<void> _select(Profile p, {bool refresh = true}) async {
    active = p;
    source = MediaSource.of(p);
    error = null;
    account = null;
    library = await store.loadLibrary(p.id) ?? Library.empty();
    favorites = store.favorites(p.id);
    history = store.history(p.id);
    await store.setString('active', p.id);
    notifyListeners();
    if (refresh) await this.refresh();
  }

  Future<void> switchProfile(Profile p) => _select(p);

  /// Verifies credentials, then saves the profile and loads its content.
  Future<void> addProfile(Profile p) async {
    final info = await MediaSource.of(p).verify();
    profiles.removeWhere((e) => e.id == p.id);
    profiles.add(p);
    await store.saveProfiles(profiles);
    await _select(p, refresh: false);
    account = info;
    await refresh();
  }

  Future<void> removeProfile(Profile p) async {
    profiles.removeWhere((e) => e.id == p.id);
    await store.saveProfiles(profiles);
    await store.deleteSecret('pw_${p.id}');
    if (active?.id == p.id) {
      active = null;
      source = null;
      library = Library.empty();
      if (profiles.isNotEmpty) await _select(profiles.first);
    }
    notifyListeners();
  }

  Future<void> updateProfileOption(Profile p) async {
    await store.saveProfiles(profiles);
    if (active?.id == p.id) {
      source = MediaSource.of(p);
      await refresh();
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final p = active, src = source;
    if (p == null || src == null || loading) return;
    loading = true;
    if (!silent) error = null;
    notifyListeners();
    try {
      final lib = await src.load();
      if (active?.id != p.id) return;
      if (!lib.isEmpty || library.isEmpty) {
        library = lib;
        await store.saveLibrary(p.id, lib);
      }
      error = null;
      try {
        account ??= await src.verify();
      } catch (_) {}
    } catch (e) {
      // Keep showing the cached library; surface the problem softly.
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---- favourites ----
  bool isFav(String id) => favorites.contains(id);
  void toggleFav(String id) {
    final p = active;
    if (p == null) return;
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    store.setFavorites(p.id, favorites);
    notifyListeners();
  }

  List<LiveChannel> get favoriteChannels => library.live.where((c) => favorites.contains(c.id)).toList();

  // Movies and series use prefixed keys so their ids never clash with channels.
  static String vodKey(VodItem v) => 'vod:${v.id}';
  static String seriesKey(SeriesItem s) => 'series:${s.id}';
  List<VodItem> get favoriteVod => library.vod.where((v) => favorites.contains(vodKey(v))).toList();
  List<SeriesItem> get favoriteSeries => library.series.where((x) => favorites.contains(seriesKey(x))).toList();

  // ---- continue watching ----
  WatchEntry? progressFor(String key) {
    for (final h in history) {
      if (h.key == key) return h;
    }
    return null;
  }

  List<WatchEntry> get continueWatching =>
      history.where((h) => !h.finished && h.positionMs > 30000).toList()
        ..sort((a, b) => b.updatedMs.compareTo(a.updatedMs));

  void saveProgress(WatchEntry e) {
    final p = active;
    if (p == null) return;
    history.removeWhere((h) => h.key == e.key);
    history.insert(0, e);
    if (history.length > 60) history = history.sublist(0, 60);
    store.setHistory(p.id, history);
    notifyListeners();
  }

  // ---- helpers ----
  List<LiveChannel> liveIn(String? catId) =>
      catId == null || catId == '*' ? library.live : library.live.where((c) => c.categoryId == catId).toList();
  List<VodItem> vodIn(String? catId) => catId == 'fav'
      ? favoriteVod
      : catId == null || catId == '*' ? library.vod : library.vod.where((c) => c.categoryId == catId).toList();
  List<SeriesItem> seriesIn(String? catId) => catId == 'fav'
      ? favoriteSeries
      : catId == null || catId == '*' ? library.series : library.series.where((c) => c.categoryId == catId).toList();

  List<VodItem> get recentVod {
    final l = [...library.vod]..sort((a, b) => b.added.compareTo(a.added));
    return l.take(20).toList();
  }

  List<SeriesItem> get recentSeries {
    final l = [...library.series]..sort((a, b) => b.added.compareTo(a.added));
    return l.take(20).toList();
  }
}
