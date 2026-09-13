import 'package:bck_agenda/src/features/service_sessions/service_session_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps official service session statuses', () {
    expect(serviceSessionStatusFromApi('OPEN'), ServiceSessionStatus.open);
    expect(serviceSessionStatusFromApi('IN_SERVICE'), ServiceSessionStatus.inService);
    expect(serviceSessionStatusFromApi('FINISHED'), ServiceSessionStatus.finished);
    expect(serviceSessionStatusFromApi('CANCELLED'), ServiceSessionStatus.cancelled);
  });

  test('parses consolidated service session totals and actual timing', () {
    final session = ServiceSession.fromJson({
      'id': 'session-1',
      'appointmentId': 'appointment-1',
      'professionalUserId': 'professional-1',
      'clientId': 'client-1',
      'clientName': 'Cliente Teste',
      'clientPhone': '27999999999',
      'status': 'FINISHED',
      'notes': 'Concluído',
      'subtotal': 120.0,
      'discountTotal': 20.0,
      'total': 100.0,
      'createdAt': '2026-09-12T12:00:00Z',
      'finishedAt': '2026-09-12T13:00:00Z',
      'arrivedAt': '2026-09-12T11:55:00Z',
      'serviceStartedAt': '2026-09-12T12:05:00Z',
      'serviceFinishedAt': '2026-09-12T12:42:00Z',
      'effectiveDurationMinutes': 37,
    });

    expect(session.total, 100);
    expect(session.discountTotal, 20);
    expect(session.isClosed, isTrue);
    expect(session.finishedAt, isNotNull);
    expect(session.arrivedAt, DateTime.parse('2026-09-12T11:55:00Z'));
    expect(session.serviceStartedAt, DateTime.parse('2026-09-12T12:05:00Z'));
    expect(session.serviceFinishedAt, DateTime.parse('2026-09-12T12:42:00Z'));
    expect(session.effectiveDurationMinutes, 37);
  });

  test('accepts open sessions without completed actual timing', () {
    final session = ServiceSession.fromJson({
      'id': 'session-open',
      'appointmentId': 'appointment-open',
      'professionalUserId': 'professional-1',
      'clientId': null,
      'clientName': 'Cliente',
      'clientPhone': null,
      'status': 'IN_SERVICE',
      'notes': null,
      'subtotal': 0,
      'discountTotal': 0,
      'total': 0,
      'createdAt': '2026-09-12T12:00:00Z',
      'finishedAt': null,
      'arrivedAt': '2026-09-12T11:58:00Z',
      'serviceStartedAt': '2026-09-12T12:00:00Z',
      'serviceFinishedAt': null,
      'effectiveDurationMinutes': null,
    });

    expect(session.isClosed, isFalse);
    expect(session.serviceStartedAt, isNotNull);
    expect(session.serviceFinishedAt, isNull);
    expect(session.effectiveDurationMinutes, isNull);
  });

  test('parses item commercial snapshot', () {
    final item = ServiceSessionItem.fromJson({
      'id': 'item-1',
      'itemType': 'SERVICE',
      'serviceId': 'service-1',
      'sourceItemId': null,
      'name': 'Corte',
      'quantity': 1,
      'unitPrice': 50,
      'discountAmount': 5,
      'lineSubtotal': 50,
      'lineTotal': 45,
    });

    expect(item.name, 'Corte');
    expect(item.unitPrice, 50);
    expect(item.lineTotal, 45);
  });
}
