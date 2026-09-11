import '../../core/api/bck_api_client.dart';
import 'team_agenda_loader.dart';

const allProfessionalsAgendaScope = '__ALL__';

/// Resolve a consulta da Agenda sem ampliar o contrato HTTP da API.
///
/// O escopo "Todos" existe apenas para Administradores na camada de UI. Cada
/// lote continua sendo consultado pela API autenticada e, portanto, sujeito ao
/// isolamento de Empresa/Grupo do servidor.
Future<List<AppointmentItem>> loadAgendaScope({
  required BckApiClient apiClient,
  required String groupId,
  required String selectedProfessionalId,
  required Iterable<ManagedUserItem> professionals,
  required DateTime from,
  required DateTime to,
}) {
  if (selectedProfessionalId == allProfessionalsAgendaScope) {
    return loadTeamAppointments(
      apiClient: apiClient,
      groupId: groupId,
      professionalUserIds: professionals.map((p) => p.id),
      from: from,
      to: to,
    );
  }
  return apiClient.appointments(
    groupId: groupId,
    professionalUserId: selectedProfessionalId,
    from: from,
    to: to,
  );
}

String agendaScopeLabel({
  required String selectedProfessionalId,
  required String currentUserId,
  required String currentUserName,
  required Iterable<ManagedUserItem> professionals,
}) {
  if (selectedProfessionalId == allProfessionalsAgendaScope) return 'Todos • equipe completa';
  if (selectedProfessionalId == currentUserId) return 'Minha agenda • $currentUserName';
  for (final professional in professionals) {
    if (professional.id == selectedProfessionalId) return professional.name;
  }
  return 'Profissional';
}
