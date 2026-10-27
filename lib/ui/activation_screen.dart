import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'widgets.dart';

/// Shown once per device when the build was made with an activation code.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _code = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;
  int _fails = 0;
  DateTime? _lockedUntil;

  Future<void> _submit() async {
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      setState(() => _error = 'محاولات كثيرة، انتظر قليلاً ثم أعد المحاولة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<AppState>().activate(_code.text);
    if (!mounted) return;
    if (!ok) {
      _fails++;
      if (_fails >= 5) _lockedUntil = DateTime.now().add(Duration(seconds: 30 * (_fails - 4)));
      setState(() {
        _busy = false;
        _error = 'الرقم السري غير صحيح';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: BrandTitle(size: 26)),
              const SizedBox(height: 32),
              const Text('تفعيل التطبيق', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('أدخل الرقم السري مرة واحدة فقط على هذا الجهاز.', style: TextStyle(color: c.muted)),
              const SizedBox(height: 20),
              TextField(
                controller: _code,
                obscureText: _hide,
                autofocus: true,
                textDirection: TextDirection.ltr,
                onSubmitted: (_) => _submit(),
                decoration: fieldDecoration(
                  context,
                  hint: 'الرقم السري',
                  prefix: const Icon(Icons.lock_outline_rounded),
                  suffix: IconButton(
                    tooltip: _hide ? 'إظهار' : 'إخفاء',
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: c.live)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'تفعيل', icon: Icons.check_rounded, busy: _busy, onPressed: _submit),
            ]),
          ),
        ),
      ),
    );
  }
}
