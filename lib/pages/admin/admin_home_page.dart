import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session_service.dart';
import '../../core/theme.dart';
import '../../core/tutorial_service.dart';
import '../../widgets/context_guide_dialog.dart';
import 'analytics_panel.dart';
import 'policies_panel.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const _tutorialKey = 'admin_home';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowGuide());
  }

  Future<void> _maybeShowGuide({bool force = false}) async {
    if (!force) {
      final shouldShow = await TutorialService.shouldShow(_tutorialKey);
      if (!shouldShow || !mounted) return;
    }
    if (!mounted) return;
    await showContextGuideDialog(
      context,
      title: 'Guía · panel administrativo',
      subtitle: 'Desde aquí supervisas la operación y revisas el modelado del negocio.',
      steps: const [
        'Monitoreo muestra KPIs, cuellos de botella, recomendaciones y exportación del reporte.',
        'Políticas te deja revisar el diseño de los flujos, sus carriles y los nodos definidos.',
        'Usa este mismo botón de ayuda cuando quieras repasar el recorrido.',
      ],
    );
    await TutorialService.markSeen(_tutorialKey);
  }

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
              tooltip: 'Mostrar guía',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _maybeShowGuide(force: true),
            ),
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
