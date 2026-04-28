import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models/analytics_model.dart';
import '../../core/theme.dart';
import '../../widgets/empty_state.dart';

class AnalyticsPanel extends StatefulWidget {
  const AnalyticsPanel({super.key});

  @override
  State<AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends State<AnalyticsPanel>
    with AutomaticKeepAliveClientMixin {
  Summary? _summary;
  BottleneckData? _bottlenecks;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getSummary(),
        api.getBottlenecks(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Summary;
        _bottlenecks = results[1] as BottleneckData;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar analítica';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 36, color: AppColors.danger),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final s = _summary!;
    final b = _bottlenecks!;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _SectionTitle('Resumen del flujo', Icons.bar_chart_outlined),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _StatCard(
                icon: Icons.account_tree_outlined,
                color: AppColors.info,
                label: 'Trámites',
                value: '${s.totalTramites}',
              ),
              _StatCard(
                icon: Icons.task_alt,
                color: AppColors.success,
                label: 'Completadas',
                value: '${s.completedTasks}',
              ),
              _StatCard(
                icon: Icons.pending_actions,
                color: AppColors.warning,
                label: 'Pendientes',
                value: '${s.pendingTasks}',
              ),
              _StatCard(
                icon: Icons.list_alt_outlined,
                color: AppColors.primary,
                label: 'Tareas totales',
                value: '${s.totalTasks}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Cuellos de botella · IA', Icons.psychology_alt_outlined),
          const SizedBox(height: 8),
          _AiInsightCard(data: b),
          const SizedBox(height: 16),
          _CriticalNodesCard(nodes: b.criticalNodes),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionTitle(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 18),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  final BottleneckData data;
  const _AiInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isAI = data.aiSource == 'gemini';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isAI ? AppColors.purple : AppColors.muted)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAI ? 'GEMINI' : 'FALLBACK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAI ? AppColors.purple : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome,
                    color: AppColors.purple, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.aiSummary.isEmpty ? 'Sin observaciones' : data.aiSummary,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            if (data.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Recomendaciones',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...data.recommendations.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(Icons.circle,
                              size: 6, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(r,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _CriticalNodesCard extends StatelessWidget {
  final List<CriticalNode> nodes;
  const _CriticalNodesCard({required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nodos críticos',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (nodes.isEmpty)
              const EmptyState(
                icon: Icons.thumb_up_alt_outlined,
                title: 'Sin nodos críticos',
                message: 'El flujo está fluyendo bien por ahora.',
              )
            else
              ...nodes.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.danger),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.nodeCode.isEmpty
                                    ? '— sin código —'
                                    : n.nodeCode,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontFamily: 'monospace'),
                              ),
                              Text(
                                'Pendientes ${n.pending} · Observadas ${n.observed} · Total ${n.total}',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
