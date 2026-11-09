import 'package:flutter/material.dart';
import '../core/l10n/app_strings.dart';
import '../core/router/app_router.dart';
import 'theme.dart';

class PaeGoApp extends StatefulWidget {
  const PaeGoApp({super.key});

  @override
  State<PaeGoApp> createState() => _PaeGoAppState();
}

class _PaeGoAppState extends State<PaeGoApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _locale = 'es';

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  void _toggleLanguage() {
    setState(() {
      _locale = _locale == 'es' ? 'en' : 'es';
      S.setLocale(_locale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      onGenerateRoute: (s) => AppRouter.generateRoute(
        s,
        _toggleTheme,
        _themeMode,
        _toggleLanguage,
        _locale,
      ),
      initialRoute: AppRouter.splash,
    );
  }
}
