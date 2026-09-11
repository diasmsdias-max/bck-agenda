import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:bck_agenda/src/features/agenda/team_agenda_loader.dart';
import 'package:flutter_test/flutter_test.dart';

AppointmentItem appointment(
  String id,
  String professionalId,
  DateTime startsAt,
) =>
    AppointmentItem(
      id: id,
      professionalUserId: professionalId,
      clientName: 'Cliente $id',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(minutes: 30)),
      status: 'SCHEDULED',
      isFitIn: false,
    );

void main() {
  test('agenda consolidada mantém ordem cronológica e profissional', () async {
    final calls = <String>[];
    final result = await consolidateTeamAppointments(
      professionalUserIds: const ['prof-2', 'prof-1'],
      loadProfessional: (professionalId) async {
        calls.add(professionalId);
        if (professionalId == 'prof-1') {
          return [
            appointment('c', 'prof-1', DateTime(2026, 9, 11, 10)),
            appointment('a', 'prof-1', DateTime(2026, 9, 11, 9)),
          ];
        }
        return [appointment('b', 'prof-2', DateTime(2026, 9, 11, 10))];
      },
    );

    expect(calls.toSet(), {'prof-1', 'prof-2'});
    expect(result.map((x) => x.id), ['a', 'c', 'b']);
    expect(result.map((x) => x.professionalUserId).toSet(), {'prof-1', 'prof-2'});
  });

  test('IDs repetidos consultam cada profissional somente uma vez', () async {
    final calls = <String, int>{};
    await consolidateTeamAppointments(
      professionalUserIds: const ['prof-1', 'prof-2', 'prof-1'],
      loadProfessional: (professionalId) async {
        calls.update(professionalId, (value) => value + 1, ifAbsent: () => 1);
        return const <AppointmentItem>[];
      },
    );

    expect(calls, {'prof-1': 1, 'prof-2': 1});
  });

  test('sem profissionais não executa consultas', () async {
    var called = false;
    final result = await consolidateTeamAppointments(
      professionalUserIds: const [],
      loadProfessional: (_) async {
        called = true;
        return const <AppointmentItem>[];
      },
    );

    expect(called, isFalse);
    expect(result, isEmpty);
  });
}
