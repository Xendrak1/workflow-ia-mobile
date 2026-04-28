import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../core/api_service.dart';
import '../core/models/ai_model.dart';
import '../core/models/policy_model.dart' as policy;
import '../core/theme.dart';

/// Contexto del trámite/tarea que se manda al backend.
class AiDictationContext {
  final String? taskTitle;
  final String? nodeName;
  final String? lane;
  final String? procedureType;
  final String? applicantName;
  final String? applicantDocument;

  const AiDictationContext({
    this.taskTitle,
    this.nodeName,
    this.lane,
    this.procedureType,
    this.applicantName,
    this.applicantDocument,
  });
}

/// Lo que devuelve el sheet cuando el usuario pulsa "Aplicar".
class AiDictationApply {
  final Map<String, dynamic> formData;
  final String? observations;
  final String? transcript;
  const AiDictationApply({
    required this.formData,
    this.observations,
    this.transcript,
  });
}

Future<AiDictationApply?> showAiDictationSheet(
  BuildContext context, {
  required List<policy.FormField> fields,
  required AiDictationContext ctx,
}) {
  return showModalBottomSheet<AiDictationApply>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AiDictationSheet(fields: fields, ctx: ctx),
    ),
  );
}

class AiDictationSheet extends StatefulWidget {
  final List<policy.FormField> fields;
  final AiDictationContext ctx;

  const AiDictationSheet({
    super.key,
    required this.fields,
    required this.ctx,
  });

  @override
  State<AiDictationSheet> createState() => _AiDictationSheetState();
}

class _AiDictationSheetState extends State<AiDictationSheet> {
  final _recorder = AudioRecorder();
  final _reportCtrl = TextEditingController();

  bool _recording = false;
  bool _processing = false;
  bool _transcribing = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _audioPath;
  String? _error;
  String? _transcriptStatus;
  TaskFormFillResult? _result;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _reportCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _result = null;
      _transcriptStatus = 'Grabando audio… al detener, lo transcribimos y pegamos el texto aquí.';
    });
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        setState(() => _error = 'Necesitas permitir el micrófono.');
        return;
      }
      final path =
          '${Directory.systemTemp.path}/dictado_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 16000,
          bitRate: 64000,
        ),
        path: path,
      );
      _elapsed = Duration.zero;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
      setState(() {
        _recording = true;
        _audioPath = path;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar la grabación: $e');
    }
  }

  Future<void> _stopAndProcess() async {
    final path = await _recorder.stop();
    _ticker?.cancel();
    setState(() {
      _recording = false;
      _audioPath = path ?? _audioPath;
      _transcriptStatus = 'Audio capturado. Iniciando transcripción…';
    });
    if (_audioPath == null) {
      setState(() => _error = 'No se grabó audio.');
      return;
    }
    await _transcribeAudio(_audioPath!);
  }

  Future<void> _processText() async {
    final text = _reportCtrl.text.trim();
    if (text.length < 3) {
      setState(() =>
          _error = 'Escribe al menos una frase con lo que quieres registrar.');
      return;
    }
    await _process(reportText: text);
  }

  Future<void> _extractFromText() async {
    final text = _reportCtrl.text.trim();
    if (text.length < 3) {
      setState(() => _error = 'Escribe al menos una frase para extraer datos localmente.');
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });
    try {
      final api = context.read<ApiService>();
      final ctx = widget.ctx;
      final res = await api.taskFormFillLocal(
        reportText: text,
        fields: widget.fields,
        taskTitle: ctx.taskTitle,
        nodeName: ctx.nodeName,
        lane: ctx.lane,
        procedureType: ctx.procedureType,
        applicantName: ctx.applicantName,
        applicantDocument: ctx.applicantDocument,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo extraer información desde el texto.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _process({required String reportText}) async {
    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });
    try {
      final api = context.read<ApiService>();
      final ctx = widget.ctx;
      final res = await api.taskFormFillFromText(
        reportText: reportText,
        fields: widget.fields,
        taskTitle: ctx.taskTitle,
        nodeName: ctx.nodeName,
        lane: ctx.lane,
        procedureType: ctx.procedureType,
        applicantName: ctx.applicantName,
        applicantDocument: ctx.applicantDocument,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Error al consultar a la IA.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    setState(() {
      _transcribing = true;
      _error = null;
      _transcriptStatus = 'Transcribiendo audio...';
    });
    try {
      final api = context.read<ApiService>();
      final result = await api.transcribeAudio(
        audioFile: File(audioPath),
        mimeType: 'audio/m4a',
      );
      if (!mounted) return;
      _reportCtrl.text = result.transcript;
      setState(() {
        _transcriptStatus = result.transcript.trim().isEmpty
            ? 'No se obtuvo texto útil desde el audio.'
            : 'Transcripción lista. Revisa el texto y luego genera o extrae.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo transcribir el audio.');
    } finally {
      if (mounted) {
        setState(() => _transcribing = false);
      }
    }
  }

  void _apply() {
    final r = _result;
    if (r == null) return;
    Navigator.of(context).pop(AiDictationApply(
      formData: r.formData,
      observations: r.observations,
      transcript: r.transcript,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _grabber(),
              _header(),
              const SizedBox(height: 14),
              if (_result != null)
                _resultPreview(_result!)
              else if (_recording)
                _recordingState()
              else if (_processing || _transcribing)
                _processingState()
              else
                _idleState(),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _errorBox(_error!),
              ],
              const SizedBox(height: 16),
              _footerButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome,
              color: AppColors.purple, size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asistente IA · dictado',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text(
                'Dicta o escribe tu informe y la IA llenará el formulario.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _idleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_transcriptStatus != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
            ),
            child: Text(
              _transcriptStatus!,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
        TextField(
          controller: _reportCtrl,
          maxLines: 5,
          minLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText:
                'Ejemplo: "El medidor está instalado correctamente, sin observaciones, fecha 25 de abril."',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _processText,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Generar con texto'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _extractFromText,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Extraer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic_none_rounded, size: 20),
              label: const Text('Grabar y transcribir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recordingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const _PulsingMic(),
          const SizedBox(height: 12),
          Text(
            'Grabando · ${_fmt(_elapsed)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Habla con claridad. Al detener, el sistema transcribe y pega el texto en el cuadro.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _stopAndProcess,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Detener y enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _processingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.purple),
          const SizedBox(height: 12),
          Text(
            _transcribing ? 'Transcribiendo audio…' : 'Procesando texto…',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _transcriptStatus ?? 'Esto puede tardar unos segundos.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _resultPreview(TaskFormFillResult r) {
    final items = widget.fields
        .map((f) => MapEntry(
              f,
              r.formData[f.key],
            ))
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: (r.isAi ? AppColors.purple : AppColors.muted)
                .withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(r.isAi ? Icons.bolt : Icons.sync_problem,
                  size: 12,
                  color: r.isAi ? AppColors.purple : AppColors.muted),
              const SizedBox(width: 4),
              Text(
                r.isAi ? 'GEMINI ${r.isFromAudio ? '· AUDIO' : ''}'.trim()
                    : 'FALLBACK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: r.isAi ? AppColors.purple : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        if (r.transcript != null && r.transcript!.isNotEmpty)
          _previewBlock('Transcripción', r.transcript!, Icons.record_voice_over),
        if (r.summary.isNotEmpty)
          _previewBlock('Resumen', r.summary, Icons.summarize_outlined),
        if (r.observations != null && r.observations!.isNotEmpty)
          _previewBlock(
              'Observaciones', r.observations!, Icons.sticky_note_2_outlined),
        const SizedBox(height: 6),
        const Text('Campos sugeridos',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'La IA no pudo inferir valores concretos. Puedes editar los campos manualmente.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          )
        else
          ...items.map((e) => _kvRow(
                e.key.label.isEmpty ? e.key.key : e.key.label,
                '${e.value}',
              )),
      ],
    );
  }

  Widget _previewBlock(String title, String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              key,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _footerButtons() {
    if (_result != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _result = null;
                _audioPath = null;
                _transcriptStatus = null;
                _reportCtrl.clear();
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(0, 46),
              ),
              child: const Text('Reintentar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Aplicar al formulario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 46),
            ),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final scale = 1.0 + 0.18 * _ctrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.mic_rounded,
                  size: 30, color: AppColors.danger),
            ),
          ),
        );
      },
    );
  }
}
