import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import 'agenda_models.dart';

/// Displays the operational actions available for an appointment.
///
/// Keeping the status/action mapping outside AgendaPage makes the main Agenda
/// screen smaller and lets the operational flow evolve without concentrating
/// navigation, rendering and transition rules in one file.
Future<String?> showAppointmentActionsSheet(
  BuildContext context, {
  required AppointmentItem appointment,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => _AppointmentActionsSheet(appointment: appointment),
  );
}

class _AppointmentActionsSheet extends StatelessWidget {
  const _AppointmentActionsSheet({required this.appointment});

  final AppointmentItem appointment;

  @override
  Widget build(BuildContext context) {
    final status = appointment.status.toUpperCase();
    final actions = <({String code, String label, IconData icon})>[];

    void add(String code, String label, IconData icon) {
      actions.add((code: code, label: label, icon: icon));
    }

    switch (status) {
      case 'SCHEDULED':
        add('CONFIRMED', 'Confirmar', Icons.check_circle_outline);
        add('WAITING', 'Cliente chegou', Icons.event_seat_outlined);
        add('RESCHEDULE', 'Remarcar', Icons.event_repeat_rounded);
        add('NO_SHOW', 'Não compareceu', Icons.person_off_outlined);
        add('CANCELLED', 'Cancelar', Icons.cancel_outlined);
      case 'CONFIRMED':
        add('WAITING', 'Cliente chegou', Icons.event_seat_outlined);
        add('IN_SERVICE', 'Iniciar atendimento', Icons.play_circle_outline);
        add('RESCHEDULE', 'Remarcar', Icons.event_repeat_rounded);
        add('NO_SHOW', 'Não compareceu', Icons.person_off_outlined);
        add('CANCELLED', 'Cancelar', Icons.cancel_outlined);
      case 'WAITING':
        add('IN_SERVICE', 'Iniciar atendimento', Icons.play_circle_outline);
        add('RESCHEDULE', 'Remarcar', Icons.event_repeat_rounded);
        add('NO_SHOW', 'Não compareceu', Icons.person_off_outlined);
        add('CANCELLED', 'Cancelar', Icons.cancel_outlined);
      case 'IN_SERVICE':
        // Finishing/cancelling an active attendance must go through the
        // operational service-session flow so totals and history stay aligned.
        add(
          'CONTINUE_SERVICE',
          'Continuar atendimento',
          Icons.play_circle_outline,
        );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appointment.clientName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Status atual: ${AgendaStatus.fromApi(appointment.status).label}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            if (actions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Este atendimento não possui novas ações operacionais.',
                ),
              )
            else
              ...actions.map(
                (action) => ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  onTap: () => Navigator.pop(context, action.code),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
