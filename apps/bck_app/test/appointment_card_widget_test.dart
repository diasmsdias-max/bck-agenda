import 'package:bck_agenda/src/core/api/bck_api_client.dart';
import 'package:bck_agenda/src/features/agenda/appointment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('card mantém horário planejado e apresenta tempos reais', (tester) async {
    final item = AppointmentItem(
      id: 'a1',
      professionalUserId: 'p1',
      clientName: 'Cliente Teste',
      startsAt: DateTime(2026, 9, 12, 10),
      endsAt: DateTime(2026, 9, 12, 10, 30),
      status: 'FINISHED',
      isFitIn: false,
      arrivedAt: DateTime(2026, 9, 12, 9, 58),
      serviceStartedAt: DateTime(2026, 9, 12, 10, 4),
      serviceFinishedAt: DateTime(2026, 9, 12, 10, 41),
      actualDurationMinutes: 37,
    );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: AppointmentCard(item: item)),
    ));

    expect(find.text('Cliente Teste'), findsOneWidget);
    expect(find.textContaining('10:00–10:30'), findsOneWidget);
    expect(find.text('Chegou 09:58'), findsOneWidget);
    expect(find.text('Início 10:04'), findsOneWidget);
    expect(find.text('Fim 10:41'), findsOneWidget);
    expect(find.text('Duração real 37 min'), findsOneWidget);
  });

  testWidgets('card apresenta atraso sem alterar status persistido', (tester) async {
    final item = AppointmentItem(
      id: 'a2',
      professionalUserId: 'p1',
      clientName: 'Cliente Atrasado',
      startsAt: DateTime.now().subtract(const Duration(hours: 1)),
      endsAt: DateTime.now().subtract(const Duration(minutes: 30)),
      status: 'CONFIRMED',
      isFitIn: false,
    );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: AppointmentCard(item: item)),
    ));

    expect(find.text('Atrasado'), findsOneWidget);
    expect(find.textContaining('Confirmado'), findsOneWidget);
  });
}
