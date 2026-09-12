import 'package:bck_agenda/src/features/service_sessions/service_session_api.dart';
import 'package:bck_agenda/src/features/service_sessions/service_session_models.dart';
import 'package:bck_agenda/src/features/service_sessions/service_session_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeServiceSessionApi extends ServiceSessionApi {
  _FakeServiceSessionApi() : super(dio: Dio());

  bool openCalled = false;

  @override
  Future<ServiceSession> open({required String appointmentId, String? notes}) async {
    openCalled = true;
    return ServiceSession(
      id: 'session-1',
      appointmentId: appointmentId,
      professionalUserId: 'professional-1',
      clientName: 'Cliente Teste',
      status: ServiceSessionStatus.open,
      subtotal: 0,
      discountTotal: 0,
      total: 0,
      createdAt: DateTime(2026, 9, 12),
    );
  }
}

void main() {
  testWidgets('opens operational attendance automatically for an appointment', (tester) async {
    final api = _FakeServiceSessionApi();

    await tester.pumpWidget(MaterialApp(
      home: ServiceSessionPage(
        api: api,
        appointmentId: 'appointment-1',
        clientName: 'Cliente Teste',
      ),
    ));
    await tester.pump();

    expect(find.text('Atendimento'), findsOneWidget);
    expect(find.text('Cliente Teste'), findsOneWidget);
    expect(api.openCalled, isTrue);
    expect(find.text('Abrir atendimento'), findsNothing);
    expect(find.text('Resumo'), findsOneWidget);
  });
}
