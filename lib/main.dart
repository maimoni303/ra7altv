import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'services/store.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/activation_screen.dart';
import 'ui/brand_anim.dart';
import 'ui/login_screen.dart';
import 'ui/shell.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    FlutterError.onError = (d) => FlutterError.presentError(d);
    final state = AppState(Store());
    runApp(ChangeNotifierProvider.value(value: state, child: const Ra7alApp()));
    await state.init();
  }, (e, s) => debugPrint('Unhandled: $e'));
}

class Ra7alApp extends StatefulWidget {
  const Ra7alApp({super.key});
  @override
  State<Ra7alApp> createState() => _Ra7alAppState();
}

class _Ra7alAppState extends State<Ra7alApp> {
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    // Let the animated logo play its intro once at launch.
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _introDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'RA7AL TV',
      // TV remotes: the centre/OK key and gamepad A activate the focused item.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
      },
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: !s.ready || !_introDone
          ? const _Splash()
          : !s.activated
              ? const ActivationScreen()
              : s.active == null
                  ? const LoginScreen()
                  : const Shell(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).shortestSide;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(child: AnimatedBrand(service: 'TV', size: (w * 0.7).clamp(220.0, 460.0))),
    );
  }
}
