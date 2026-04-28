class FormField {
  final String key;
  final String label;
  final String fieldType; // texto | numero | booleano | archivo | imagen | select
  final bool required;
  final List<String> options;

  const FormField({
    required this.key,
    required this.label,
    required this.fieldType,
    required this.required,
    required this.options,
  });

  factory FormField.fromJson(Map<String, dynamic> json) => FormField(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        fieldType: json['field_type'] as String? ?? 'texto',
        required: json['required'] as bool? ?? false,
        options: (json['options'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

class PolicyNode {
  final String id;
  final String code;
  final String name;
  final String lane;
  final String nodeType; // inicio | tarea | decision | paralelo | fin
  final List<FormField> formFields;

  const PolicyNode({
    required this.id,
    required this.code,
    required this.name,
    required this.lane,
    required this.nodeType,
    required this.formFields,
  });

  factory PolicyNode.fromJson(Map<String, dynamic> json) => PolicyNode(
        id: json['_id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lane: json['lane'] as String? ?? '',
        nodeType: json['node_type'] as String? ?? 'tarea',
        formFields: (json['form_fields'] as List<dynamic>?)
                ?.map((e) => FormField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class Policy {
  final String id;
  final String name;
  final String? description;
  final String procedureType;
  final String status; // borrador | validada | publicada | archivada
  final int version;
  final List<PolicyNode> nodes;

  const Policy({
    required this.id,
    required this.name,
    this.description,
    required this.procedureType,
    required this.status,
    required this.version,
    required this.nodes,
  });

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
        id: json['_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        procedureType: json['procedure_type'] as String? ?? '',
        status: json['status'] as String? ?? 'borrador',
        version: json['version'] as int? ?? 1,
        nodes: (json['nodes'] as List<dynamic>?)
                ?.map((e) => PolicyNode.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
