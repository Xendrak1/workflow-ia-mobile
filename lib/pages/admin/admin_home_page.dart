import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session_service.dart';
import '../../core/theme.dart';
import 'analytics_panel.dart';
import 'policies_panel.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Panel administrativo'),
              Text(
                session.fullName ?? '—',
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Mi monitor',
              icon: const Icon(Icons.inbox_outlined),
              onPressed: () => context.go('/inbox'),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<SessionService>().clear();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.insights_outlined), text: 'Monitoreo'),
              Tab(icon: Icon(Icons.policy_outlined), text: 'Políticas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AnalyticsPanel(),
            PoliciesPanel(),
          ],
        ),
      ),
    );
  }
}
