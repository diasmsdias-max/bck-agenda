import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EP05 agenda API models', () {
    test('AppointmentItem preserva profissional e estado de encaixe', () {
      final item = AppointmentItem.fromJson({
        'id': 'appointment-1',
        'professionalUserId': 'professional-1',
        'clientName': 'Cliente Teste',
        'startsAt': '2026-09-12T10:00:00Z',
        'endsAt': '2026-09-12T10:30:00Z',
        'status': 'CONFIRMED',
        'isFitIn': true,
      });

      expect(item.id, 'appointment-1');
      expect(item.professionalUserId, 'professional-1');
      expect(item.status, 'CONFIRMED');
      expect(item.isFitIn, isTrue);
    });

    test('AppointmentAvailability preserva todos os conflitos simultâneos', () {
      final availability = AppointmentAvailability.fromJson({
        'available': false,
        'conflicts': [
          {
            'id': 'appointment-1',
            'professionalUserId': 'professional-1',
            'clientName': 'Cliente A',
            'startsAt': '2026-09-12T10:00:00Z',
            'endsAt': '2026-09-12T10:30:00Z',
            'status': 'CONFIRMED',
            'isFitIn': false,
          },
          {
            'id': 'appointment-2',
            'professionalUserId': 'professional-1',
            'clientName': 'Cliente B',
            'startsAt': '2026-09-12T10:10:00Z',
            'endsAt': '2026-09-12T10:40:00Z',
            'status': 'SCHEDULED',
            'isFitIn': true,
          },
        ],
      });

      expect(availability.available, isFalse);
      expect(availability.conflicts, hasLength(2));
      expect(availability.conflicts.map((x) => x.id),
          containsAll(<String>['appointment-1', 'appointment-2']));
    });

    test('RescheduleResult mantém vínculo entre original e novo atendimento', () {
      final result = RescheduleResult.fromJson({
        'originalAppointmentId': 'appointment-old',
        'newAppointment': {
          'id': 'appointment-new',
          'professionalUserId': 'professional-2',
          'clientName': 'Cliente Remarcado',
          'startsAt': '2026-09-13T14:00:00Z',
          'endsAt': '2026-09-13T15:00:00Z',
          'status': 'SCHEDULED',
          'isFitIn': false,
        },
      });

      expect(result.originalAppointmentId, 'appointment-old');
      expect(result.newAppointment.id, 'appointment-new');
      expect(result.newAppointment.professionalUserId, 'professional-2');
    });
  });
}
