import 'package:bck_agenda/src/features/service_sessions/service_session_api.dart';
import 'package:bck_agenda/src/features/service_sessions/service_session_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows operational entry point for an appointment', (tester) async {
    final api = ServiceSessionApi(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

    await tester.pumpWidget(MaterialApp(
      home: ServiceSessionPage(
        api: api,
        appointmentId: 'appointment-1',
        clientName: 'Cliente Teste',
      ),
    ));

    expect(find.text('Atendimento'), findsOneWidget);
    expect(find.text('Cliente Teste'), findsOneWidget);
    expect(find.text('Abrir atendimento'), findsOneWidget);
  });
}
