import 'package:flutter_test/flutter_test.dart';
import 'package:bck_agenda/src/features/agenda/appointment_card_details.dart';

void main() {
  test('marca atraso antes da chegada', () {
    final details = AppointmentCardDetails.build(
      startsAt: DateTime(2026, 9, 11, 10),
      status: 'CONFIRMED',
      now: DateTime(2026, 9, 11, 10, 15),
    );
    expect(details, contains('Atrasado'));
  });

  test('mostra chegada e remove atraso atual', () {
    final details = AppointmentCardDetails.build(
      startsAt: DateTime(2026, 9, 11, 10),
      status: 'WAITING',
      arrivedAt: DateTime(2026, 9, 11, 10, 8),
      now: DateTime(2026, 9, 11, 10, 15),
    );
    expect(details, isNot(contains('Atrasado')));
    expect(details, contains('Chegou 10:08'));
  });

  test('mostra início fim e duração real', () {
    final details = AppointmentCardDetails.build(
      startsAt: DateTime(2026, 9, 11, 10),
      status: 'FINISHED',
      serviceStartedAt: DateTime(2026, 9, 11, 10, 12),
      serviceFinishedAt: DateTime(2026, 9, 11, 10, 59),
      actualDurationMinutes: 47,
    );
    expect(details, containsAll(<String>[
      'Início 10:12',
      'Fim 10:59',
      'Duração real 47 min',
    ]));
  });
}
