class TaskFormFillResult {
  final String source;
  final String? model;
  final String? transcript;
  final String summary;
  final String? observations;
  final Map<String, dynamic> formData;

  const TaskFormFillResult({
    required this.source,
    required this.summary,
    required this.formData,
    this.model,
    this.transcript,
    this.observations,
  });

  bool get isAi => source == 'gemini' || source == 'gemini-audio';
  bool get isFromAudio =>
      source == 'gemini-audio' || source == 'fallback-audio';

  factory TaskFormFillResult.fromJson(Map<String, dynamic> json) =>
      TaskFormFillResult(
        source: json['source'] as String? ?? 'fallback',
        model: json['model'] as String?,
        transcript: json['transcript'] as String?,
        summary: json['summary'] as String? ?? '',
        observations: json['observations'] as String?,
        formData:
            (json['form_data'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
}

class AudioTranscriptionResult {
  final String source;
  final String? model;
  final String transcript;
  final String? message;

  const AudioTranscriptionResult({
    required this.source,
    required this.transcript,
    this.model,
    this.message,
  });

  factory AudioTranscriptionResult.fromJson(Map<String, dynamic> json) =>
      AudioTranscriptionResult(
        source: json['source'] as String? ?? 'local',
        model: json['model'] as String?,
        transcript: json['transcript'] as String? ?? '',
        message: json['message'] as String?,
      );
}
