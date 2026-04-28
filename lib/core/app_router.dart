import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/admin/admin_home_page.dart';
import '../pages/admin/policy_detail_page.dart';
import '../pages/inbox/inbox_page.dart';
import '../pages/login/login_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/task_detail/task_detail_page.dart';
import 'session_service.dart';

GoRouter buildRouter(SessionService session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final loggedIn = session.isLoggedIn;
      final loc = state.matchedLocation;
      final isLogin = loc == '/login';
      final isSplash = loc == '/';

      if (isSplash) return null;

      if (!loggedIn && !isLogin) return '/login';
      if (loggedIn && isLogin) {
        return session.isAdmin ? '/admin' : '/inbox';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/inbox', builder: (_, _) => const InboxPage()),
      GoRoute(
        path: '/tasks/:id',
        builder: (_, state) => TaskDetailPage(taskId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminHomePage()),
      GoRoute(
        path: '/admin/policies/:id',
        builder: (_, state) =>
            PolicyDetailPage(policyId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.matchedLocation}')),
    ),
  );
}
