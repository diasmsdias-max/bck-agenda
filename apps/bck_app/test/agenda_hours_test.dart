import 'package:flutter_test/flutter_test.dart';
import 'package:bck_agenda/src/features/agenda/agenda_hours.dart';

void main() {
  test('agenda diária cobre as 24 horas sem lacunas', () {
    expect(agendaDayHours.length, 24);
    expect(agendaDayHours.first, 0);
    expect(agendaDayHours.last, 23);
    expect(agendaDayHours, List<int>.generate(24, (index) => index));
  });
}
