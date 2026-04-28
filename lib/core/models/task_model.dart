class EvidenceItem {
  final String id;
  final String fileName;
  final String? fileUrl;
  final String? note;
  final String? contentType;
  final int? sizeBytes;

  const EvidenceItem({
    required this.id,
    required this.fileName,
    this.fileUrl,
    this.note,
    this.contentType,
    this.sizeBytes,
  });

  factory EvidenceItem.fromJson(Map<String, dynamic> json) => EvidenceItem(
        id: json['_id'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        fileUrl: json['file_url'] as String?,
        note: json['note'] as String?,
        contentType: json['content_type'] as String?,
        sizeBytes: json['size_bytes'] as int?,
      );
}

class Task {
  final String id;
  final String tramiteId;
  final String policyId;
  final String nodeCode;
  final String title;
  final String status; // pendiente | en_proceso | observada | completada
  final String? assignedDepartment;
  final String? assignedUserId;
  final Map<String, dynamic> formData;
  final String? observations;
  final List<EvidenceItem> evidences;
  final String? startedAt;
  final String? finishedAt;
  final String createdAt;

  const Task({
    required this.id,
    required this.tramiteId,
    required this.policyId,
    required this.nodeCode,
    required this.title,
    required this.status,
    this.assignedDepartment,
    this.assignedUserId,
    required this.formData,
    this.observations,
    required this.evidences,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['_id'] as String? ?? '',
        tramiteId: json['tramite_id'] as String? ?? '',
        policyId: json['policy_id'] as String? ?? '',
        nodeCode: json['node_code'] as String? ?? '',
        title: json['title'] as String? ?? 'Tarea sin título',
        status: json['status'] as String? ?? 'pendiente',
        assignedDepartment: json['assigned_department'] as String?,
        assignedUserId: json['assigned_user_id'] as String?,
        formData: (json['form_data'] as Map<String, dynamic>?) ?? {},
        observations: json['observations'] as String?,
        evidences: (json['evidences'] as List<dynamic>?)
                ?.map((e) => EvidenceItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        startedAt: json['started_at'] as String?,
        finishedAt: json['finished_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}
