import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models/task_model.dart';
import '../../core/session_service.dart';
import '../../core/theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/task_card.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Timer? _autoTimer;
  List<Task> _tasks = const [];
  bool _firstLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _refresh();
    _autoTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    final api = context.read<ApiService>();
    final session = context.read<SessionService>();
    try {
      final data = await _load(api, session);
      if (!mounted) return;
      setState(() {
        _tasks = data;
        _firstLoad = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _firstLoad = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar al servidor';
        _firstLoad = false;
      });
    }
  }

  Future<List<Task>> _load(ApiService api, SessionService session) async {
    final all = await api.listTasks();
    if (session.isFuncionario) {
      final dept = session.department;
      final uid = session.userId;
      return all.where((t) {
        final byUser = uid != null && t.assignedUserId == uid;
        final byDept = dept != null &&
            (t.assignedDepartment ?? '').toLowerCase() == dept.toLowerCase();
        // Sin asignación → mostrar también para que pueda tomarla.
        final unassigned =
            (t.assignedDepartment == null || t.assignedDepartment!.isEmpty) &&
                (t.assignedUserId == null || t.assignedUserId!.isEmpty);
        return byUser || byDept || unassigned;
      }).toList();
    }
    return all;
  }

  List<Task> _byStatus(String status) =>
      _tasks.where((t) => t.status == status).toList();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final pendientes = _byStatus('pendiente');
    final enProceso = _byStatus('en_proceso');
    final observadas = _byStatus('observada');
    final completadas = _byStatus('completada');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi monitor'),
        actions: [
          if (session.isAdmin || session.isSupervisor)
            IconButton(
              tooltip: 'Panel admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.go('/admin'),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<SessionService>().clear();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: [
            Tab(text: 'Pendientes (${pendientes.length})'),
            Tab(text: 'En proceso (${enProceso.length})'),
            Tab(text: 'Observadas (${observadas.length})'),
            Tab(text: 'Completadas (${completadas.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _Header(session: session),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ),
              ]),
            ),
          Expanded(
            child: _firstLoad
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tab,
                    children: [
                      _TaskList(tasks: pendientes, onRefresh: _refresh),
                      _TaskList(tasks: enProceso, onRefresh: _refresh),
                      _TaskList(tasks: observadas, onRefresh: _refresh),
                      _TaskList(tasks: completadas, onRefresh: _refresh),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final SessionService session;
  const _Header({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(
              session.initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.fullName ?? 'Funcionario',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${(session.role ?? '').toUpperCase()}'
                  '${session.department != null ? ' · ${session.department}' : ''}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.notifications_active_outlined,
              color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Future<void> Function() onRefresh;

  const _TaskList({required this.tasks, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Sin tareas en este estado',
              message: 'Desliza hacia abajo para refrescar.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (_, i) {
          final t = tasks[i];
          return TaskCard(
            task: t,
            onTap: () => context.push('/tasks/${t.id}'),
          );
        },
      ),
    );
  }
}
