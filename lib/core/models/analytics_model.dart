class Summary {
  final int totalTramites;
  final int totalTasks;
  final int pendingTasks;
  final int completedTasks;

  const Summary({
    required this.totalTramites,
    required this.totalTasks,
    required this.pendingTasks,
    required this.completedTasks,
  });

  factory Summary.fromJson(Map<String, dynamic> json) => Summary(
        totalTramites: json['total_tramites'] as int? ?? 0,
        totalTasks: json['total_tasks'] as int? ?? 0,
        pendingTasks: json['pending_tasks'] as int? ?? 0,
        completedTasks: json['completed_tasks'] as int? ?? 0,
      );
}

class CriticalNode {
  final String nodeCode;
  final int total;
  final int pending;
  final int observed;

  const CriticalNode({
    required this.nodeCode,
    required this.total,
    required this.pending,
    required this.observed,
  });

  factory CriticalNode.fromJson(Map<String, dynamic> json) => CriticalNode(
        nodeCode: json['_id'] as String? ?? '',
        total: json['total'] as int? ?? 0,
        pending: json['pending'] as int? ?? 0,
        observed: json['observed'] as int? ?? 0,
      );
}

class BottleneckData {
  final List<CriticalNode> criticalNodes;
  final List<String> recommendations;
  final String aiSummary;
  final String aiSource;

  const BottleneckData({
    required this.criticalNodes,
    required this.recommendations,
    required this.aiSummary,
    required this.aiSource,
  });

  factory BottleneckData.fromJson(Map<String, dynamic> json) => BottleneckData(
        criticalNodes: (json['critical_nodes'] as List<dynamic>?)
                ?.map((e) => CriticalNode.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        recommendations:
            (json['recommendations'] as List<dynamic>?)?.cast<String>() ?? [],
        aiSummary: json['ai_summary'] as String? ?? '',
        aiSource: json['ai_source'] as String? ?? 'fallback',
      );
}
