import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models/policy_model.dart' as policy;
import '../../core/models/task_model.dart';
import '../../core/theme.dart';
import '../../widgets/ai_dictation_sheet.dart';
import '../../widgets/dynamic_form_field.dart';
import '../../widgets/status_badge.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  Task? _task;
  policy.PolicyNode? _node;
  String? _procedureType;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _completing = false;

  final Map<String, dynamic> _formData = {};
  final TextEditingController _observationsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final task = await api.getTask(widget.taskId);
      policy.PolicyNode? node;
      String? procedureType;
      if (task.policyId.isNotEmpty) {
        try {
          final pol = await api.getPolicy(task.policyId);
          procedureType = pol.procedureType;
          node = pol.nodes.firstWhere(
            (n) => n.code == task.nodeCode,
            orElse: () => const policy.PolicyNode(
              id: '',
              code: '',
              name: '',
              lane: '',
              nodeType: 'tarea',
              formFields: <policy.FormField>[],
            ),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _task = task;
        _node = node;
        _procedureType = procedureType;
        _formData
          ..clear()
          ..addAll(task.formData);
        _observationsCtrl.text = task.observations ?? '';
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
          _error = 'No se pudo cargar la tarea';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    final task = _task;
    if (task == null) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final updated = await api.updateTask(
        task.id,
        formData: _formData,
        observations: _observationsCtrl.text,
      );
      if (!mounted) return;
      setState(() => _task = updated);
      _toast('Cambios guardados');
    } on ApiException catch (e) {
      _toast(e.message, danger: true);
    } catch (_) {
      _toast('No se pudo guardar', danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    await _uploadFile(File(picked.path));
  }

  Future<void> _addFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    if (res == null || res.files.single.path == null) return;
    await _uploadFile(File(res.files.single.path!));
  }

  Future<void> _uploadFile(File file, {String? note}) async {
    final task = _task;
    if (task == null) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      await api.uploadEvidence(task.id, file, note: note);
      _toast('Evidencia subida');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message, danger: true);
    } catch (_) {
      _toast('No se pudo subir la evidencia', danger: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTextNote() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Evidencia textual'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Describe tu evidencia o informe…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    final tmp = File(
      '${Directory.systemTemp.path}/nota_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await tmp.writeAsString(note);
    await _uploadFile(tmp, note: note);
    if (await tmp.exists()) {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  Future<void> _complete() async {
    final task = _task;
    if (task == null) return;

    final missing = (_node?.formFields ?? [])
        .where((f) =>
            f.required &&
            (f.fieldType != 'archivo' && f.fieldType != 'imagen') &&
            (_formData[f.key] == null || '${_formData[f.key]}'.isEmpty))
        .map((f) => f.label.isEmpty ? f.key : f.label)
        .toList();

    if (missing.isNotEmpty) {
      _toast('Faltan campos requeridos: ${missing.join(', ')}', danger: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Marcar como finalizada'),
        content: const Text(
          'Se enviará al siguiente nodo automáticamente. ¿Confirmas?',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final api = context.read<ApiService>();

    setState(() => _completing = true);
    try {
      await api.updateTask(task.id,
          formData: _formData, observations: _observationsCtrl.text);
      final res = await api.completeTask(task.id);
      if (!mounted) return;
      _toast(
        'Tarea finalizada · enrutada a ${(res['next_task_ids'] as List?)?.length ?? 0} nodo(s)',
      );
      context.pop();
    } on ApiException catch (e) {
      _toast(e.message, danger: true);
    } catch (_) {
      _toast('No se pudo finalizar', danger: true);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _openAiAssistant() async {
    final fields = _node?.formFields ?? const <policy.FormField>[];
    if (fields.isEmpty) {
      _toast('Esta tarea no tiene formulario que llenar.', danger: true);
      return;
    }
    final task = _task;
    final ctx = AiDictationContext(
      taskTitle: task?.title,
      nodeName: _node?.name,
      lane: _node?.lane,
      procedureType: _procedureType,
    );
    final result = await showAiDictationSheet(context, fields: fields, ctx: ctx);
    if (result == null || !mounted) return;
    final hasObservationField = fields.any((f) {
      final probe = '${f.key} ${f.label}'.toLowerCase();
      return probe.contains('observ') ||
          probe.contains('descripcion') ||
          probe.contains('descripción') ||
          probe.contains('detalle') ||
          probe.contains('comentario') ||
          probe.contains('nota');
    });
    setState(() {
      for (final f in fields) {
        final v = result.formData[f.key];
        if (v == null) continue;
        if (v is String && v.isEmpty) continue;
        _formData[f.key] = v;
      }
      if (!hasObservationField &&
          result.observations != null &&
          result.observations!.isNotEmpty) {
        final existing = _observationsCtrl.text.trim();
        _observationsCtrl.text = existing.isEmpty
            ? result.observations!
            : '$existing\n\n${result.observations!}';
      }
    });
    final src = result.transcript != null && result.transcript!.isNotEmpty
        ? 'Transcripción aplicada · revisa los campos antes de guardar.'
        : 'Sugerencia aplicada · revisa los campos antes de guardar.';
    _toast(src);
  }

  void _toast(String msg, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: danger ? AppColors.danger : AppColors.surface,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de tarea'),
        actions: [
          if (_task != null && _task!.status != 'completada')
            IconButton(
              tooltip: 'Guardar borrador',
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              onPressed: _saving ? null : _saveDraft,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 36),
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
    final task = _task!;
    final readOnly = task.status == 'completada';
    final fields = _node?.formFields ?? const <policy.FormField>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _headerCard(task),
        if (!readOnly && fields.isNotEmpty) ...[
          const SizedBox(height: 12),
          _aiAssistantCard(),
        ],
        const SizedBox(height: 16),
        _sectionTitle('Formulario', Icons.dynamic_form_outlined),
        if (fields.isEmpty)
          _muted('Esta tarea no tiene un formulario configurado.')
        else
          ...fields.map((f) => DynamicFormFieldWidget(
                field: f,
                value: _formData[f.key],
                readOnly: readOnly,
                onChanged: (v) => setState(() => _formData[f.key] = v),
              )),
        const SizedBox(height: 16),
        _sectionTitle('Observaciones', Icons.notes_outlined),
        TextField(
          controller: _observationsCtrl,
          readOnly: readOnly,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Notas internas, contexto, decisiones tomadas…'),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Evidencias', Icons.attach_file_outlined),
        if (!readOnly) _evidenceActions(),
        const SizedBox(height: 8),
        _evidenceList(task),
      ],
    );
  }

  Widget _headerCard(Task task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(task.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ),
                StatusBadge(task.status),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _meta(Icons.tag, task.tramiteId),
                if (task.assignedDepartment != null &&
                    task.assignedDepartment!.isNotEmpty)
                  _meta(Icons.business_outlined, task.assignedDepartment!),
                if (_node != null && _node!.lane.isNotEmpty)
                  _meta(Icons.view_column_outlined, 'Lane ${_node!.lane}'),
                _meta(Icons.label_outline, 'Nodo ${task.nodeCode}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiAssistantCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _saving ? null : _openAiAssistant,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic_none_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistente IA · Dictado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Dicta tu informe y Gemini llenará el formulario por ti.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _muted(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      );

  Widget _evidenceActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _evBtn(Icons.camera_alt_outlined, 'Cámara',
            () => _addImage(ImageSource.camera)),
        _evBtn(Icons.image_outlined, 'Galería',
            () => _addImage(ImageSource.gallery)),
        _evBtn(Icons.attach_file, 'Archivo', _addFile),
        _evBtn(Icons.text_snippet_outlined, 'Texto', _addTextNote),
      ],
    );
  }

  Widget _evBtn(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: _saving ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surfaceAlt,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _evidenceList(Task task) {
    if (task.evidences.isEmpty) {
      return _muted('Sin evidencias registradas todavía.');
    }
    return Column(
      children: task.evidences.map((ev) {
        final isImg = (ev.contentType ?? '').startsWith('image/');
        final api = context.read<ApiService>();
        final url = api.evidenceUrl(ev.fileUrl);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: SizedBox(
              width: 40,
              height: 40,
              child: isImg && url.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) {
                        return const Icon(Icons.broken_image_outlined,
                            color: AppColors.muted);
                      }),
                    )
                  : Icon(
                      isImg ? Icons.image_outlined : Icons.insert_drive_file,
                      color: AppColors.muted),
            ),
            title: Text(ev.fileName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            subtitle: ev.note != null && ev.note!.isNotEmpty
                ? Text(ev.note!,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12))
                : (ev.sizeBytes != null
                    ? Text('${(ev.sizeBytes! / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12))
                    : null),
          ),
        );
      }).toList(),
    );
  }

  Widget? _buildBottomBar() {
    final task = _task;
    if (task == null || task.status == 'completada') return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          onPressed: _completing ? null : _complete,
          icon: _completing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: const Text('Marcar como finalizada'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}
