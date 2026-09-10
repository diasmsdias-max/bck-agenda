import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:bck_agenda/src/features/onboarding/welcome_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BCK Agenda renders first-run onboarding', (tester) async {
    final apiClient = BckApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:5080')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomePage(apiClient: apiClient),
      ),
    );

    expect(find.text('BCK Agenda'), findsOneWidget);
    expect(find.text('Organize. Atenda. Gerencie.'), findsOneWidget);
    expect(find.text('Criar minha empresa'), findsOneWidget);
    expect(find.text('Sincronizar com empresa existente'), findsOneWidget);
  });
}
