import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:bck_agenda/src/core/theme/theme_controller.dart';
import 'package:bck_agenda/src/features/onboarding/connect_company_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  BckApiClient apiClient() => BckApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:5080')),
      );

  Widget page() => MaterialApp(
        home: ConnectCompanyPage(
          apiClient: apiClient(),
          themeController: ThemeController(),
        ),
      );

  testWidgets('pareamento novo exige código e nome do aparelho', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Empresa existente'), findsOneWidget);
    expect(find.text('Código de conexão'), findsOneWidget);
    expect(find.text('Nome deste aparelho'), findsOneWidget);
    expect(find.text('Usar outro código'), findsNothing);
  });

  testWidgets('pareamento pendente mostra somente login para concluir',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'installation.deviceId': 'device-1',
      'pairing.pending.groupId': 'group-1',
      'pairing.pending.deviceId': 'device-1',
    });

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Concluir conexão'), findsWidgets);
    expect(
      find.text(
        'Este aparelho já foi autorizado. Entre com seu usuário e senha para concluir a conexão.',
      ),
      findsOneWidget,
    );
    expect(find.text('Código de conexão'), findsNothing);
    expect(find.text('Nome deste aparelho'), findsNothing);
    expect(find.text('Seu usuário'), findsOneWidget);
    expect(find.text('Sua senha'), findsOneWidget);
    expect(find.text('Usar outro código'), findsOneWidget);
  });

  testWidgets('usar outro código limpa recuperação e volta ao pareamento',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'installation.deviceId': 'device-1',
      'pairing.pending.groupId': 'group-1',
      'pairing.pending.deviceId': 'device-1',
    });

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar outro código'));
    await tester.pumpAndSettle();

    expect(find.text('Empresa existente'), findsOneWidget);
    expect(find.text('Código de conexão'), findsOneWidget);
    expect(find.text('Nome deste aparelho'), findsOneWidget);
    expect(find.text('Usar outro código'), findsNothing);
  });
}
