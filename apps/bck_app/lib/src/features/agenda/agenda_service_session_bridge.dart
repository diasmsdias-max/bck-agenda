import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import '../service_sessions/service_session_launcher.dart';

/// Opens the operational attendance flow from an Agenda appointment.
///
/// Keeping this bridge inside the Agenda feature avoids duplicating the
/// canonical [AppointmentItem] model while keeping the navigation dependency
/// explicit and easy to test/remove if routing changes later.
Future<bool?> openAgendaServiceSession(
  BuildContext context, {
  required StoredSession session,
  required AppointmentItem appointment,
}) {
  return openServiceSessionFromAgenda(
    context,
    session: session,
    appointment: appointment,
  );
}
