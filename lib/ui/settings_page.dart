import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 36.0 : 20.0;

    Widget card(List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        );

    return ListView(padding: EdgeInsets.fromLTRB(pad, wide ? 28 : 16, pad, 32), children: [
      const Text('الإعدادات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      Text('المظهر', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      card([
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('داكن')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('فاتح')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('حسب الجهاز')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setTheme(v.first),
          ),
        ),
      ]),
      Row(children: [
        Expanded(child: Text('الاشتراكات', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600))),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(pushed: true))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة اشتراك'),
        ),
      ]),
      const SizedBox(height: 8),
      card([
        for (final p in s.profiles)
          ListTile(
            leading: Icon(p.type == SourceType.xtream ? Icons.dns_outlined : Icons.playlist_play_rounded,
                color: s.active?.id == p.id ? c.accent : c.faint),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(p.type == SourceType.xtream ? 'Xtream · ${p.username}' : 'M3U', style: TextStyle(color: c.muted)),
            onTap: s.active?.id == p.id ? null : () => s.switchProfile(p),
            trailing: PopupMenuButton<String>(
              tooltip: 'خيارات',
              onSelected: (v) async {
                if (v == 'fmt') {
                  p.liveFormat = p.liveFormat == 'ts' ? 'm3u8' : 'ts';
                  await s.updateProfileOption(p);
                } else if (v == 'tls') {
                  p.allowInsecure = !p.allowInsecure;
                  await s.updateProfileOption(p);
                } else if (v == 'del') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('حذف الاشتراك؟'),
                      content: Text('سيتم حذف «${p.name}» وبياناته من هذا الجهاز.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (ok == true) await s.removeProfile(p);
                }
              },
              itemBuilder: (_) => [
                if (p.type == SourceType.xtream)
                  PopupMenuItem(value: 'fmt', child: Text('صيغة البث: ${p.liveFormat == 'ts' ? 'TS ← HLS' : 'HLS ← TS'}')),
                PopupMenuItem(value: 'tls', child: Text(p.allowInsecure ? 'إيقاف قبول الشهادات غير الموثوقة' : 'قبول الشهادات غير الموثوقة')),
                const PopupMenuItem(value: 'del', child: Text('حذف')),
              ],
            ),
          ),
      ]),
      Text('المحتوى', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      card([
        ListTile(
          leading: const Icon(Icons.refresh_rounded),
          title: const Text('تحديث القوائم الآن'),
          subtitle: s.library.fetchedAt.millisecondsSinceEpoch > 0
              ? Text('آخر تحديث: ${fmtTime(s.library.fetchedAt)}', style: TextStyle(color: c.muted))
              : null,
          trailing: s.loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
          onTap: s.loading ? null : () => s.refresh(),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('مسح الذاكرة المؤقتة'),
          onTap: () async {
            await s.store.clearCache();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح الذاكرة المؤقتة')));
            }
            await s.refresh();
          },
        ),
      ]),
      Text('حول التطبيق', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      card([
        const ListTile(leading: Ra7alLogo(size: 32), title: Text('RA7AlTV'), subtitle: Text('الإصدار 1.0.0 · مفتوح المصدر GPL-3.0')),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('التراخيص'),
          onTap: () => showLicensePage(context: context, applicationName: 'RA7AlTV', applicationVersion: '1.0.0'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text('RA7AlTV مشغّل فقط ولا يوفّر أي قنوات أو محتوى. استخدمه مع اشتراك من مزوّد مرخّص.',
              style: TextStyle(color: c.faint, fontSize: 13)),
        ),
      ]),
    ]);
  }
}
