import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:bck_agenda/src/features/agenda/agenda_layout.dart';
import 'package:flutter_test/flutter_test.dart';

AppointmentItem appointment(
  String id,
  DateTime start, {
  bool fitIn = false,
}) =>
    AppointmentItem(
      id: id,
      professionalUserId: 'professional-1',
      clientName: 'Cliente $id',
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 30)),
      status: 'SCHEDULED',
      isFitIn: fitIn,
    );

void main() {
  test('preserva todos os atendimentos e encaixes iniciados na mesma hora', () {
    final base = DateTime(2026, 9, 12, 10);
    final regular = appointment('regular', base);
    final fitIn = appointment(
      'fit-in',
      base.add(const Duration(minutes: 15)),
      fitIn: true,
    );

    final grouped = appointmentsByLocalHour([fitIn, regular]);

    expect(grouped[10], hasLength(2));
    expect(grouped[10]!.map((item) => item.id), ['regular', 'fit-in']);
  });

  test('não mistura atendimentos de horas diferentes', () {
    final grouped = appointmentsByLocalHour([
      appointment('a', DateTime(2026, 9, 12, 9, 45)),
      appointment('b', DateTime(2026, 9, 12, 10, 5)),
      appointment('c', DateTime(2026, 9, 12, 11, 30)),
    ]);

    expect(grouped.keys.toSet(), {9, 10, 11});
    expect(grouped.values.expand((items) => items), hasLength(3));
  });

  test('ordena horários iguais de forma determinística', () {
    final start = DateTime(2026, 9, 12, 14);
    final grouped = appointmentsByLocalHour([
      appointment('fit', start, fitIn: true),
      appointment('normal', start),
    ]);

    expect(grouped[14]!.map((item) => item.id), ['normal', 'fit']);
  });
}
