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

class Ra7alApp extends StatelessWidget {
  const Ra7alApp({super.key});

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
      home: !s.ready
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
}
