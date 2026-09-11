import '../../core/api/bck_api_client.dart';

/// Agrupa os atendimentos pela hora local de início sem descartar encaixes.
///
/// A Agenda pode conter mais de um atendimento no mesmo intervalo quando um
/// encaixe é autorizado. A camada visual deve consumir todos os itens do grupo,
/// em ordem cronológica, em vez de renderizar somente o primeiro.
Map<int, List<AppointmentItem>> appointmentsByLocalHour(
  Iterable<AppointmentItem> appointments,
) {
  final result = <int, List<AppointmentItem>>{};
  for (final appointment in appointments) {
    final hour = appointment.startsAt.toLocal().hour;
    (result[hour] ??= <AppointmentItem>[]).add(appointment);
  }
  for (final items in result.values) {
    items.sort((a, b) {
      final start = a.startsAt.compareTo(b.startsAt);
      if (start != 0) return start;
      if (a.isFitIn != b.isFitIn) return a.isFitIn ? 1 : -1;
      return a.id.compareTo(b.id);
    });
  }
  return result;
}
