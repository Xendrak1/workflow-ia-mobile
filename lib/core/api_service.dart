import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'models/ai_model.dart';
import 'models/task_model.dart';
import 'models/policy_model.dart' as policy;
import 'models/analytics_model.dart';

class ExportedReport {
  final List<int> bytes;
  final String fileName;
  final String mimeType;

  const ExportedReport({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

// Excepción tipada para errores de la API
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String? Function() _tokenProvider;

  ApiService(this._tokenProvider);

  Map<String, String> get _headers {
    final token = _tokenProvider();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Construye la URL completa de un archivo de evidencia
  String evidenceUrl(String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) return '';
    if (fileUrl.startsWith('http')) return fileUrl;
    // kBaseUrl termina en /api — quitamos el sufijo para la URL de archivos
    final base = kBaseUrl.endsWith('/api')
        ? kBaseUrl.substring(0, kBaseUrl.length - 4)
        : kBaseUrl;
    return '$base$fileUrl';
  }

  Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final res = await http.get(Uri.parse('$kBaseUrl$path'), headers: _headers);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return parse(body['data']);
  }

  Future<T> _post<T>(String path, Map<String, dynamic> payload,
      T Function(dynamic) parse) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return parse(body['data']);
  }

  Future<T> _put<T>(String path, Map<String, dynamic> payload,
      T Function(dynamic) parse) async {
    final res = await http.put(
      Uri.parse('$kBaseUrl$path'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return parse(body['data']);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String detail = 'Error ${res.statusCode}';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      detail = body['detail'] as String? ?? detail;
    } catch (_) {}
    throw ApiException(res.statusCode, detail);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Tasks ───────────────────────────────────────────────────────────────────

  Future<List<Task>> listTasks() => _get(
        '/tasks',
        (data) => (data as List<dynamic>)
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<Task> getTask(String taskId) => _get(
        '/tasks/$taskId',
        (data) => Task.fromJson(data as Map<String, dynamic>),
      );

  Future<Task> updateTask(
    String taskId, {
    Map<String, dynamic>? formData,
    String? observations,
  }) =>
      _put(
        '/tasks/$taskId',
        {
          'form_data': formData ?? const <String, dynamic>{},
          if (observations != null) 'observations': observations,
        },
        (data) => Task.fromJson(data as Map<String, dynamic>),
      );

  Future<Map<String, dynamic>> completeTask(String taskId) => _post(
        '/tasks/$taskId/complete',
        {},
        (data) => data as Map<String, dynamic>,
      );

  // Sube evidencia como base64. Recibe un File del sistema de archivos.
  Future<Map<String, dynamic>> uploadEvidence(
    String taskId,
    File file, {
    String? note,
  }) async {
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final contentType = _mimeFromExt(ext);

    return _post(
      '/tasks/$taskId/evidences',
      {
        'file_name': fileName,
        'file_base64': base64,
        'content_type': contentType,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      (data) => data as Map<String, dynamic>,
    );
  }

  String _mimeFromExt(String ext) {
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'pdf': 'application/pdf',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ── Policies (Admin) ─────────────────────────────────────────────────────────

  Future<List<policy.Policy>> listPolicies() => _get(
        '/policies',
        (data) => (data as List<dynamic>)
            .map((e) => policy.Policy.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<policy.Policy> getPolicy(String policyId) => _get(
        '/policies/$policyId',
        (data) => policy.Policy.fromJson(data as Map<String, dynamic>),
      );

  // ── Analytics (Admin / Supervisor) ───────────────────────────────────────────

  Future<Summary> getSummary() => _get(
        '/analytics/summary',
        (data) => Summary.fromJson(data as Map<String, dynamic>),
      );

  Future<BottleneckData> getBottlenecks() => _get(
        '/analytics/bottlenecks',
        (data) => BottleneckData.fromJson(data as Map<String, dynamic>),
      );

  Future<ExportedReport> exportAnalyticsReport(String format) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/analytics/report?format=$format'),
      headers: _headers,
    );
    _checkStatus(res);
    final lower = format.toLowerCase();
    return ExportedReport(
      bytes: res.bodyBytes,
      fileName: lower == 'csv' ? 'workflow-report.csv' : 'workflow-report.json',
      mimeType: lower == 'csv' ? 'text/csv' : 'application/json',
    );
  }

  // ── AI (Asistente Gemini) ────────────────────────────────────────────────────

  /// Llena un formulario a partir de un informe textual.
  Future<TaskFormFillResult> taskFormFillFromText({
    required String reportText,
    required List<policy.FormField> fields,
    String? taskTitle,
    String? nodeName,
    String? lane,
    String? procedureType,
    String? applicantName,
    String? applicantDocument,
  }) =>
      _post(
        '/ai/task-form-fill',
        {
          'report_text': reportText,
          if (taskTitle != null) 'task_title': taskTitle,
          if (nodeName != null) 'node_name': nodeName,
          if (lane != null) 'lane': lane,
          if (procedureType != null) 'procedure_type': procedureType,
          if (applicantName != null) 'applicant_name': applicantName,
          if (applicantDocument != null) 'applicant_document': applicantDocument,
          'fields': fields.map(_formFieldToJson).toList(),
        },
        (data) => TaskFormFillResult.fromJson(data as Map<String, dynamic>),
      );

  Future<TaskFormFillResult> taskFormFillLocal({
    required String reportText,
    required List<policy.FormField> fields,
    String? taskTitle,
    String? nodeName,
    String? lane,
    String? procedureType,
    String? applicantName,
    String? applicantDocument,
  }) =>
      _post(
        '/ai/task-form-fill-local',
        {
          'report_text': reportText,
          if (taskTitle != null) 'task_title': taskTitle,
          if (nodeName != null) 'node_name': nodeName,
          if (lane != null) 'lane': lane,
          if (procedureType != null) 'procedure_type': procedureType,
          if (applicantName != null) 'applicant_name': applicantName,
          if (applicantDocument != null) 'applicant_document': applicantDocument,
          'fields': fields.map(_formFieldToJson).toList(),
        },
        (data) => TaskFormFillResult.fromJson(data as Map<String, dynamic>),
      );

  Future<AudioTranscriptionResult> transcribeAudio({
    required File audioFile,
    required String mimeType,
  }) async {
    final bytes = await audioFile.readAsBytes();
    return _post(
      '/ai/transcribe-audio',
      {
        'audio_base64': base64Encode(bytes),
        'mime_type': mimeType,
      },
      (data) => AudioTranscriptionResult.fromJson(data as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> _formFieldToJson(policy.FormField f) => {
        'key': f.key,
        'label': f.label,
        'field_type': f.fieldType,
        'required': f.required,
        'options': f.options,
      };
}
