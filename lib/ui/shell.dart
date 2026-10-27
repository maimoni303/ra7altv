import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'home_page.dart';
import 'live_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'vod_page.dart';
import 'widgets.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  static void go(BuildContext context, int index) => context.findAncestorStateOfType<_ShellState>()?.go(index);
  @override
  State<Shell> createState() => _ShellState();
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _items = [
  _NavItem(Icons.home_rounded, 'الرئيسية'),
  _NavItem(Icons.live_tv_rounded, 'البث المباشر'),
  _NavItem(Icons.movie_outlined, 'الأفلام'),
  _NavItem(Icons.video_library_outlined, 'المسلسلات'),
  _NavItem(Icons.search_rounded, 'البحث'),
  _NavItem(Icons.settings_outlined, 'الإعدادات'),
];

class _ShellState extends State<Shell> {
  int _index = 0;
  void go(int i) => setState(() => _index = i);

  Widget _page() {
    switch (_index) {
      case 1:
        return const LivePage();
      case 2:
        return const VodPage(series: false);
      case 3:
        return const VodPage(series: true);
      case 4:
        return const SearchPage();
      case 5:
        return const SettingsPage();
      default:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.watch<AppState>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = KeyedSubtree(key: ValueKey(_index), child: _page());

    if (wide) {
      return Scaffold(
        body: Row(children: [
          Container(
            width: 232,
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
            decoration: BoxDecoration(color: c.rail, border: BorderDirectional(end: BorderSide(color: c.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 24), child: BrandTitle()),
              for (var i = 0; i < 5; i++) _railItem(i),
              const Spacer(),
              _railItem(5),
              const SizedBox(height: 8),
              if (s.active != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('الاشتراك النشط', style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 2),
                    Text(s.active!.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    if (s.account?.expires != null)
                      Text('ينتهي: ${_date(s.account!.expires!)}', style: TextStyle(fontSize: 12, color: c.muted)),
                  ]),
                ),
            ]),
          ),
          Expanded(child: body),
        ]),
      );
    }

    // Phone layout: bottom navigation (search lives in the Home header).
    const map = [0, 1, 2, 3, 5];
    final sel = map.indexOf(_index);
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        backgroundColor: c.rail,
        indicatorColor: c.active,
        selectedIndex: sel < 0 ? 0 : sel,
        onDestinationSelected: (i) => go(map[i]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.live_tv_rounded), label: 'مباشر'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'أفلام'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'مسلسلات'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _railItem(int i) {
    final c = context.c;
    final on = _index == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: on ? c.active : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => go(i),
          child: SizedBox(
            height: 44,
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(_items[i].icon, size: 20, color: on ? c.text : c.muted),
              const SizedBox(width: 12),
              Text(_items[i].label,
                  style: TextStyle(fontSize: 15, color: on ? c.text : c.muted, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
