import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/login/login_screen.dart';
import '../../features/auth/register/register_screen.dart';
import '../../features/auth/splash/splash_screen.dart';
import '../../features/home/home_shell.dart';

class AppRouter {
  AppRouter._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';

  static Route<dynamic> generateRoute(
    RouteSettings s,
    VoidCallback onToggleTheme,
    ThemeMode themeMode,
    VoidCallback onToggleLanguage,
    String locale,
  ) {
    switch (s.name) {
      case splash:
        return _fade(const SplashScreen());
      case login:
        return _slide(const LoginScreen());
      case register:
        return _slide(const RegisterScreen());
      case home:
        final user = s.arguments as AppUser;
        return _fade(
          HomeShell(
            user: user,
            onToggleTheme: onToggleTheme,
            themeMode: themeMode,
            onToggleLanguage: onToggleLanguage,
            locale: locale,
          ),
        );
      default:
        return _fade(_NotFound());
    }
  }

  static PageRoute _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  static PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: anim, child: child),
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(S.pageNotFound)));
}
