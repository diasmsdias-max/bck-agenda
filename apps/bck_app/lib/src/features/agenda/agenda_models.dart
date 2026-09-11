import 'package:flutter/material.dart';

enum AgendaViewMode { day, week, month }

enum AgendaStatus {
  scheduled('Agendado', Icons.event_available_rounded),
  confirmed('Confirmado', Icons.verified_rounded),
  waiting('Aguardando', Icons.hourglass_top_rounded),
  inService('Em atendimento', Icons.content_cut_rounded),
  finished('Finalizado', Icons.check_circle_rounded),
  cancelled('Cancelado', Icons.cancel_rounded),
  noShow('Não compareceu', Icons.person_off_rounded),
  rescheduled('Remarcado', Icons.update_rounded);

  const AgendaStatus(this.label, this.icon);
  final String label;
  final IconData icon;

  static AgendaStatus fromApi(String value) {
    final normalized = value.trim().toLowerCase();
    return AgendaStatus.values.firstWhere(
      (status) => status.label.toLowerCase() == normalized,
      orElse: () => AgendaStatus.scheduled,
    );
  }
}

class AgendaPalette {
  static const scheduled = Color(0xFF4D9DE0);
  static const confirmed = Color(0xFF4CAF78);
  static const waiting = Color(0xFFE3A43B);
  static const inService = Color(0xFFB28BE8);
  static const finished = Color(0xFF7A8796);
  static const cancelled = Color(0xFFD86464);
  static const noShow = Color(0xFFB86A6A);
  static const rescheduled = Color(0xFF5CB8B2);

  static Color forStatus(AgendaStatus status) => switch (status) {
        AgendaStatus.scheduled => scheduled,
        AgendaStatus.confirmed => confirmed,
        AgendaStatus.waiting => waiting,
        AgendaStatus.inService => inService,
        AgendaStatus.finished => finished,
        AgendaStatus.cancelled => cancelled,
        AgendaStatus.noShow => noShow,
        AgendaStatus.rescheduled => rescheduled,
      };
}
