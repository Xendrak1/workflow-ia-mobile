import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models/policy_model.dart';
import '../../core/theme.dart';
import '../../widgets/status_badge.dart';

class PolicyDetailPage extends StatefulWidget {
  final String policyId;
  const PolicyDetailPage({super.key, required this.policyId});

  @override
  State<PolicyDetailPage> createState() => _PolicyDetailPageState();
}

class _PolicyDetailPageState extends State<PolicyDetailPage> {
  Policy? _policy;
  bool _loading = true;
  String? _error;

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
      final p = await api.getPolicy(widget.policyId);
      if (!mounted) return;
      setState(() {
        _policy = p;
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
          _error = 'No se pudo cargar';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de negocio')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final p = _policy!;
    final lanes = <String, List<PolicyNode>>{};
    for (final n in p.nodes) {
      lanes.putIfAbsent(n.lane.isEmpty ? 'Sin carril' : n.lane, () => []).add(n);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge(p.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${p.procedureType} · v${p.version}',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12)),
                if (p.description != null && p.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(p.description!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Carriles y nodos',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
        if (lanes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Esta política aún no tiene nodos.',
                style: TextStyle(color: AppColors.muted)),
          )
        else
          ...lanes.entries.map((e) => _LaneSection(lane: e.key, nodes: e.value)),
      ],
    );
  }
}

class _LaneSection extends StatelessWidget {
  final String lane;
  final List<PolicyNode> nodes;

  const _LaneSection({required this.lane, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_column_outlined,
                    color: AppColors.muted, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(lane,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${nodes.length} nodos',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: AppColors.border, height: 12),
            ...nodes.map((n) => _NodeTile(node: n)),
          ],
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final PolicyNode node;
  const _NodeTile({required this.node});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(node.nodeType);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_typeIcon(node.nodeType), color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${node.code} · ${node.nodeType}',
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                if (node.formFields.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${node.formFields.length} campos',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String t) => switch (t) {
        'inicio' => AppColors.success,
        'fin' => AppColors.danger,
        'decision' => AppColors.warning,
        'fork' || 'paralelo' => AppColors.info,
        'join' => AppColors.purple,
        _ => AppColors.primary,
      };

  IconData _typeIcon(String t) => switch (t) {
        'inicio' => Icons.play_arrow_rounded,
        'fin' => Icons.stop_rounded,
        'decision' => Icons.alt_route_outlined,
        'fork' || 'paralelo' => Icons.call_split,
        'join' => Icons.call_merge,
        _ => Icons.assignment_outlined,
      };
}
