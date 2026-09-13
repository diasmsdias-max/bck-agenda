import 'package:flutter/material.dart';

/// An operational action that can be offered for an appointment status.
class AppointmentAction {
  const AppointmentAction({
    required this.code,
    required this.label,
    required this.icon,
  });

  final String code;
  final String label;
  final IconData icon;
}

/// Returns the actions that the Agenda may offer for a canonical API status.
///
/// The server remains the final authority for status transitions. This mapping
/// only controls which actions are presented by the client.
List<AppointmentAction> appointmentActionsForStatus(String status) {
  AppointmentAction action(String code, String label, IconData icon) =>
      AppointmentAction(code: code, label: label, icon: icon);

  return switch (status.trim().toUpperCase()) {
    'SCHEDULED' => [
        action('CONFIRMED', 'Confirmar', Icons.check_circle_outline),
        action('WAITING', 'Cliente chegou', Icons.event_seat_outlined),
        action('RESCHEDULE', 'Remarcar', Icons.event_repeat_rounded),
        action('NO_SHOW', 'Não compareceu', Icons.person_off_outlined),
        action('CANCELLED', 'Cancelar', Icons.cancel_outlined),
      ],
    'CONFIRMED' => [
        action('WAITING', 'Cliente chegou', Icons.event_seat_outlined),
        action('IN_SERVICE', 'Iniciar atendimento', Icons.play_circle_outline),
        action('RESCHEDULE', 'Remarcar', Icons.event_repeat_rounded),
        action('NO_SHOW', 'Não compareceu', Icons.person_off_outlined),
        action('CANCELLED', 'Cancelar', Icons.cancel_outlined),
      ],
    'WAITING' => [
        action('IN_SERVICE', 'Iniciar atendimento', Icons.play_circle_outline),
        action('RESCHEDULE', 'Remarcar', Icons.event_repeat_rounded),
        action('NO_SHOW', 'Não compareceu', Icons.person_off_outlined),
        action('CANCELLED', 'Cancelar', Icons.cancel_outlined),
      ],
    'IN_SERVICE' => [
        // Active attendance must be completed from the operational flow so
        // service-session totals, history and payment preparation stay aligned.
        action(
          'CONTINUE_SERVICE',
          'Continuar atendimento',
          Icons.play_circle_outline,
        ),
      ],
    _ => const <AppointmentAction>[],
  };
}
