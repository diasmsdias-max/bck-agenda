import 'package:flutter_test/flutter_test.dart';
import 'package:bck_agenda/src/features/agenda/agenda_models.dart';

void main() {
  test('mapeia todos os códigos oficiais da API para o status visual', () {
    expect(AgendaStatus.fromApi('SCHEDULED'), AgendaStatus.scheduled);
    expect(AgendaStatus.fromApi('CONFIRMED'), AgendaStatus.confirmed);
    expect(AgendaStatus.fromApi('WAITING'), AgendaStatus.waiting);
    expect(AgendaStatus.fromApi('IN_SERVICE'), AgendaStatus.inService);
    expect(AgendaStatus.fromApi('FINISHED'), AgendaStatus.finished);
    expect(AgendaStatus.fromApi('CANCELLED'), AgendaStatus.cancelled);
    expect(AgendaStatus.fromApi('NO_SHOW'), AgendaStatus.noShow);
    expect(AgendaStatus.fromApi('RESCHEDULED'), AgendaStatus.rescheduled);
  });

  test('mantém compatibilidade com códigos legados tolerados', () {
    expect(AgendaStatus.fromApi('COMPLETED'), AgendaStatus.finished);
    expect(AgendaStatus.fromApi('CANCELED'), AgendaStatus.cancelled);
  });

  test('normaliza caixa e espaços recebidos da API', () {
    expect(AgendaStatus.fromApi('  confirmed  '), AgendaStatus.confirmed);
    expect(AgendaStatus.fromApi('in_service'), AgendaStatus.inService);
  });
}
