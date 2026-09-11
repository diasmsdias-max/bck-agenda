import 'package:flutter_test/flutter_test.dart';
import 'package:bck_agenda/src/features/agenda/appointment_timing.dart';

void main() {
  group('AppointmentTiming.isLate', () {
    final start = DateTime.utc(2026, 9, 11, 12);

    test('marca agendamento pendente após o horário como atrasado', () {
      expect(
        AppointmentTiming.isLate(
          startsAt: start,
          status: 'SCHEDULED',
          now: start.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('não marca como atrasado antes do horário', () {
      expect(
        AppointmentTiming.isLate(
          startsAt: start,
          status: 'CONFIRMED',
          now: start.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('chegada registrada encerra o atraso visual', () {
      expect(
        AppointmentTiming.isLate(
          startsAt: start,
          status: 'WAITING',
          arrivedAt: start.add(const Duration(minutes: 5)),
          now: start.add(const Duration(minutes: 10)),
        ),
        isFalse,
      );
    });

    test('estados encerrados nunca aparecem como atraso atual', () {
      for (final status in ['FINISHED', 'CANCELLED', 'NO_SHOW', 'RESCHEDULED']) {
        expect(
          AppointmentTiming.isLate(
            startsAt: start,
            status: status,
            now: start.add(const Duration(hours: 2)),
          ),
          isFalse,
        );
      }
    });
  });

  group('AppointmentTiming.actualDurationMinutes', () {
    test('calcula duração somente com início e término', () {
      final start = DateTime.utc(2026, 9, 11, 12);
      expect(
        AppointmentTiming.actualDurationMinutes(
          serviceStartedAt: start,
          serviceFinishedAt: start.add(const Duration(minutes: 47)),
        ),
        47,
      );
      expect(AppointmentTiming.actualDurationMinutes(serviceStartedAt: start), isNull);
    });

    test('rejeita término anterior ao início', () {
      final start = DateTime.utc(2026, 9, 11, 12);
      expect(
        AppointmentTiming.actualDurationMinutes(
          serviceStartedAt: start,
          serviceFinishedAt: start.subtract(const Duration(minutes: 1)),
        ),
        isNull,
      );
    });
  });
}
