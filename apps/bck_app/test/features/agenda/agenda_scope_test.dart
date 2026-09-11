import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:bck_agenda/src/features/agenda/agenda_scope.dart';
import 'package:flutter_test/flutter_test.dart';

ManagedUserItem professional(String id, String name) => ManagedUserItem(
  id: id,
  name: name,
  profile: 'USER',
  isOwner: false,
  servesClients: true,
  active: true,
  permissionVersion: 1,
  permissions: const [],
);

void main() {
  final professionals = [professional('me', 'Michael'), professional('p2', 'Ana')];

  test('identifica visão consolidada Todos', () {
    expect(
      agendaScopeLabel(
        selectedProfessionalId: allProfessionalsAgendaScope,
        currentUserId: 'me',
        currentUserName: 'Michael',
        professionals: professionals,
      ),
      'Todos • equipe completa',
    );
  });

  test('distingue Minha agenda e profissional individual', () {
    expect(
      agendaScopeLabel(
        selectedProfessionalId: 'me',
        currentUserId: 'me',
        currentUserName: 'Michael',
        professionals: professionals,
      ),
      'Minha agenda • Michael',
    );
    expect(
      agendaScopeLabel(
        selectedProfessionalId: 'p2',
        currentUserId: 'me',
        currentUserName: 'Michael',
        professionals: professionals,
      ),
      'Ana',
    );
  });
}
