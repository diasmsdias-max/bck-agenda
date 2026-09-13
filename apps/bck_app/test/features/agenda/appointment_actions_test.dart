import 'package:bck_agenda/src/features/agenda/appointment_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmed and waiting may start operational attendance', () {
    for (final status in ['CONFIRMED', 'WAITING']) {
      final codes = appointmentActionsForStatus(status)
          .map((action) => action.code)
          .toList();
      expect(codes, contains('IN_SERVICE'));
    }
  });

  test('scheduled appointment cannot start attendance directly', () {
    final codes = appointmentActionsForStatus('SCHEDULED')
        .map((action) => action.code)
        .toList();
    expect(codes, isNot(contains('IN_SERVICE')));
  });

  test('active attendance can only continue through operational flow', () {
    final actions = appointmentActionsForStatus('IN_SERVICE');
    expect(actions, hasLength(1));
    expect(actions.single.code, 'CONTINUE_SERVICE');
    expect(actions.single.label, 'Continuar atendimento');
  });

  test('closed appointment has no operational action', () {
    for (final status in ['FINISHED', 'CANCELLED', 'NO_SHOW', 'RESCHEDULED']) {
      expect(appointmentActionsForStatus(status), isEmpty);
    }
  });
}
