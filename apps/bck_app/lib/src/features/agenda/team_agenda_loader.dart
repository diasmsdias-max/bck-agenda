import '../../core/api/bck_api_client.dart';

/// Carrega, em paralelo, as agendas dos profissionais visíveis ao Administrador
/// e devolve uma única linha do tempo ordenada.
///
/// A API continua aplicando o isolamento do tenant a cada consulta. A
/// consolidação acontece apenas no cliente autenticado como Administrador,
/// evitando introduzir um endpoint amplo antes de a experiência "Todos" estar
/// estabilizada.
Future<List<AppointmentItem>> loadTeamAppointments({
  required BckApiClient apiClient,
  required String groupId,
  required Iterable<String> professionalUserIds,
  required DateTime from,
  required DateTime to,
}) async {
  final ids = professionalUserIds.toSet().toList(growable: false);
  if (ids.isEmpty) return const <AppointmentItem>[];

  final batches = await Future.wait(
    ids.map(
      (professionalUserId) => apiClient.appointments(
        groupId: groupId,
        professionalUserId: professionalUserId,
        from: from,
        to: to,
      ),
    ),
  );

  final appointments = batches.expand((items) => items).toList(growable: false);
  appointments.sort((a, b) {
    final byStart = a.startsAt.compareTo(b.startsAt);
    if (byStart != 0) return byStart;
    return a.professionalUserId.compareTo(b.professionalUserId);
  });
  return appointments;
}
