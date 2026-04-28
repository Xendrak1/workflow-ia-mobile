import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (String, Color) _resolve(String status) => switch (status) {
        'pendiente' => ('Pendiente', const Color(0xFFEF4444)),
        'en_proceso' => ('En proceso', const Color(0xFFF59E0B)),
        'observada' => ('Observada', const Color(0xFF8B5CF6)),
        'completada' => ('Completada', const Color(0xFF10B981)),
        'vencida' => ('Vencida', const Color(0xFFDC2626)),
        'publicada' => ('Publicada', const Color(0xFF10B981)),
        'validada' => ('Validada', const Color(0xFF3B82F6)),
        'borrador' => ('Borrador', const Color(0xFF6B7280)),
        'archivada' => ('Archivada', const Color(0xFF6B7280)),
        'registrado' => ('Registrado', const Color(0xFF3B82F6)),
        'completado' => ('Completado', const Color(0xFF10B981)),
        'observado' => ('Observado', const Color(0xFF8B5CF6)),
        'rechazado' => ('Rechazado', const Color(0xFFDC2626)),
        _ => (status, const Color(0xFF6B7280)),
      };
}
