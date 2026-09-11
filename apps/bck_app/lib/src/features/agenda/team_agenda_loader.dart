import '../../core/api/bck_api_client.dart';

typedef ProfessionalAppointmentsLoader = Future<List<AppointmentItem>> Function(
  String professionalUserId,
);

/// Consolida as agendas dos profissionais em uma única linha do tempo.
///
/// IDs repetidos são removidos antes das consultas. O desempate de horários
/// iguais usa o profissional e, por fim, o ID do atendimento para manter uma
/// ordem determinística na visão administrativa "Todos".
Future<List<AppointmentItem>> consolidateTeamAppointments({
  required Iterable<String> professionalUserIds,
  required ProfessionalAppointmentsLoader loadProfessional,
}) async {
  final ids = professionalUserIds.toSet().toList(growable: false);
  if (ids.isEmpty) return const <AppointmentItem>[];

  final batches = await Future.wait(ids.map(loadProfessional));
  final appointments = batches.expand((items) => items).toList(growable: false);
  appointments.sort((a, b) {
    final byStart = a.startsAt.compareTo(b.startsAt);
    if (byStart != 0) return byStart;
    final byProfessional = a.professionalUserId.compareTo(b.professionalUserId);
    if (byProfessional != 0) return byProfessional;
    return a.id.compareTo(b.id);
  });
  return appointments;
}

/// Carrega, em paralelo, as agendas dos profissionais visíveis ao Administrador.
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
}) =>
    consolidateTeamAppointments(
      professionalUserIds: professionalUserIds,
      loadProfessional: (professionalUserId) => apiClient.appointments(
        groupId: groupId,
        professionalUserId: professionalUserId,
        from: from,
        to: to,
      ),
    );
