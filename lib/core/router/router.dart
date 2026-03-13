import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:music/features/auth/login_screen.dart';
import 'package:music/features/discovery/discovery_page.dart';
import 'package:music/features/home/home_page.dart';
import 'package:music/features/library/duplicate_cleaning_page.dart';
import 'package:music/features/library/library_page.dart';
import 'package:music/features/player/player_page.dart';
import 'package:music/features/settings/settings_page.dart';
import 'package:music/features/shell/main_shell.dart';
import 'package:music/features/tasks/tasks_page.dart';

import '../auth/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // 注意：不再在这里 ref.watch(authServiceProvider)，否则会导致 GoRouter 实例反复重建
  // 我们使用 refreshListenable 来让 GoRouter 响应状态变化

  return GoRouter(
    initialLocation: '/home',
    // 使用通知器作为刷新信号
    refreshListenable: _RouterRefreshStream(ref),
    redirect: (context, state) {
      // 这里的逻辑在状态变化时会被调用
      final auth = ref.read(authServiceProvider);
      final isLoggedIn = auth.isAuthenticated;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryPage(),
          ),
          GoRoute(
            path: '/discovery',
            builder: (context, state) => const DiscoveryPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(path: '/tasks', builder: (context, state) => const TasksPage()),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PlayerPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/library/duplicates',
        builder: (context, state) => const DuplicateCleaningPage(),
      ),
    ],
  );
});

/// 将 Riverpod 状态转换为 GoRouter 可识别的 Listenable
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Ref ref) {
    ref.listen(authServiceProvider, (previous, next) => notifyListeners());
  }
}
