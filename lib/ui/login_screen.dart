import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/net.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'widgets.dart';

class LoginScreen extends StatefulWidget {
  final bool pushed;
  const LoginScreen({super.key, this.pushed = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  SourceType _type = SourceType.xtream;
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _m3u = TextEditingController();
  final _epg = TextEditingController();
  bool _insecure = true, _busy = false, _hide = true;
  String _format = 'ts';
  String? _error;

  Future<void> _connect() async {
    final isX = _type == SourceType.xtream;
    if (isX && (_server.text.trim().isEmpty || _user.text.trim().isEmpty || _pass.text.isEmpty)) {
      setState(() => _error = 'أكمل رابط الخادم واسم المستخدم وكلمة المرور');
      return;
    }
    if (!isX && _m3u.text.trim().isEmpty) {
      setState(() => _error = 'أدخل رابط قائمة M3U');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? (isX ? 'اشتراكي' : 'قائمتي') : _name.text.trim(),
      type: _type,
      server: isX ? normalizeServer(_server.text) : _m3u.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
      epgUrl: _epg.text.trim(),
      allowInsecure: _insecure,
      liveFormat: _format,
    );
    try {
      await context.read<AppState>().addProfile(p);
      if (mounted && widget.pushed) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController ctl,
      {String? hint, bool ltr = false, bool secret = false, TextInputType? type}) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 14, color: c.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          obscureText: secret && _hide,
          keyboardType: type,
          autocorrect: false,
          enableSuggestions: !secret,
          textDirection: ltr ? TextDirection.ltr : null,
          decoration: fieldDecoration(
            context,
            hint: hint,
            suffix: secret
                ? IconButton(
                    tooltip: _hide ? 'إظهار' : 'إخفاء',
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  )
                : null,
          ),
        ),
      ]),
    );
  }

  Widget _form() {
    final c = context.c;
    final isX = _type == SourceType.xtream;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('إضافة اشتراك', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('اختر طريقة الاتصال بمزوّد الخدمة', style: TextStyle(color: c.muted, fontSize: 15)),
      const SizedBox(height: 20),
      SegmentedButton<SourceType>(
        segments: const [
          ButtonSegment(value: SourceType.xtream, label: Text('Xtream Codes')),
          ButtonSegment(value: SourceType.m3u, label: Text('رابط M3U')),
        ],
        selected: {_type},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _type = s.first),
      ),
      const SizedBox(height: 20),
      _field('اسم الاشتراك', _name, hint: 'مثال: البيت'),
      if (isX) ...[
        _field('رابط الخادم', _server, hint: 'http://example.com:8080', ltr: true, type: TextInputType.url),
        _field('اسم المستخدم', _user, ltr: true),
        _field('كلمة المرور', _pass, ltr: true, secret: true),
      ] else ...[
        _field('رابط قائمة M3U', _m3u, hint: 'https://example.com/playlist.m3u', ltr: true, type: TextInputType.url),
        _field('رابط دليل البرامج XMLTV (اختياري)', _epg, hint: 'https://example.com/epg.xml', ltr: true),
      ],
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('إعدادات متقدمة', style: TextStyle(color: c.muted, fontSize: 14)),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _insecure,
              onChanged: (v) => setState(() => _insecure = v),
              title: const Text('قبول الشهادات غير الموثوقة'),
              subtitle: Text('مفيد لخوادم IPTV ذات شهادات SSL ذاتية', style: TextStyle(color: c.faint, fontSize: 12)),
            ),
            if (isX)
              Row(children: [
                const Expanded(child: Text('صيغة البث المباشر')),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ts', label: Text('TS')),
                    ButtonSegment(value: 'm3u8', label: Text('HLS')),
                  ],
                  selected: {_format},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _format = s.first),
                ),
              ]),
          ],
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: TextStyle(color: c.live)),
        ),
      const SizedBox(height: 16),
      PrimaryButton(label: 'اتصال وتحميل القوائم', busy: _busy, onPressed: _connect),
      const SizedBox(height: 16),
      Text('بياناتك تُحفظ مشفّرة على جهازك فقط.', textAlign: TextAlign.center, style: TextStyle(color: c.faint, fontSize: 13)),
    ]);
  }

  Widget _intro() {
    final c = context.c;
    Widget point(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(Icons.check_rounded, color: c.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 15))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const BrandTitle(size: 24),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مشغّلك المفتوح\nلكل اشتراكاتك', style: TextStyle(fontSize: 38, height: 1.35, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Text('مجاني ومفتوح المصدر، بلا إعلانات وبلا تتبّع.', style: TextStyle(fontSize: 16, color: c.muted, height: 1.7)),
        const SizedBox(height: 18),
        point('Xtream Codes و M3U و XMLTV'),
        point('بياناتك مخزّنة على جهازك فقط'),
        point('ثيم داكن وفاتح تختار بينهما متى شئت'),
      ]),
      Text('RA7AlTV لا يوفّر أي محتوى. استخدم اشتراكاً من مزوّد مرخّص.', style: TextStyle(color: c.faint, fontSize: 13)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: _form()),
      ),
    );
    return Scaffold(
      appBar: widget.pushed ? AppBar(backgroundColor: Colors.transparent, elevation: 0) : null,
      body: SafeArea(
        child: wide
            ? Row(children: [
                Container(
                  width: 500,
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(color: c.rail, border: BorderDirectional(end: BorderSide(color: c.line))),
                  child: _intro(),
                ),
                Expanded(child: form),
              ])
            : Column(children: [
                if (!widget.pushed) const Padding(padding: EdgeInsets.only(top: 24), child: BrandTitle()),
                Expanded(child: form),
              ]),
      ),
    );
  }
}
