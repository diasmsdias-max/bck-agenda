import 'package:bck_agenda/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BCK Agenda renders foundation screen', (tester) async {
    await tester.pumpWidget(const BckAgendaApp());

    expect(find.text('BCK Agenda'), findsOneWidget);
    expect(find.text('Organize. Atenda. Gerencie.'), findsOneWidget);
    expect(find.text('Testar conexão com a API'), findsOneWidget);
  });
}
