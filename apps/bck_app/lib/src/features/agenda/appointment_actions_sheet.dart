import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import 'agenda_models.dart';
import 'appointment_actions.dart';

/// Displays the operational actions available for an appointment.
///
/// Keeping this sheet outside AgendaPage makes the main Agenda screen smaller
/// and keeps presentation separate from the status/action mapping.
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
    final actions = appointmentActionsForStatus(appointment.status);

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
