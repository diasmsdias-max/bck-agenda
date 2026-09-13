import 'package:bck_agenda/src/features/service_sessions/service_session_api.dart';
import 'package:bck_agenda/src/features/service_sessions/service_session_models.dart';
import 'package:bck_agenda/src/features/service_sessions/service_session_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeServiceSessionApi extends ServiceSessionApi {
  _FakeServiceSessionApi({this.existing, this.lookupError}) : super(dio: Dio());
  final ServiceSession? existing;
  final Object? lookupError;
  bool lookupCalled = false;
  bool openCalled = false;
  @override
  Future<ServiceSession?> getByAppointment(String appointmentId) async { lookupCalled = true; if (lookupError != null) throw lookupError!; return existing; }
  @override
  Future<ServiceSession> open({required String appointmentId, String? notes, String? idempotencyKey}) async { openCalled = true; return _session(appointmentId: appointmentId); }
}

ServiceSession _session({String appointmentId = 'appointment-1', ServiceSessionStatus status = ServiceSessionStatus.open, DateTime? arrivedAt, DateTime? serviceStartedAt, DateTime? serviceFinishedAt, int? effectiveDurationMinutes}) => ServiceSession(
  id: 'session-1', appointmentId: appointmentId, professionalUserId: 'professional-1', clientName: 'Cliente Teste', status: status,
  subtotal: 0, discountTotal: 0, total: 0, createdAt: DateTime(2026, 9, 12), arrivedAt: arrivedAt, serviceStartedAt: serviceStartedAt,
  serviceFinishedAt: serviceFinishedAt, effectiveDurationMinutes: effectiveDurationMinutes,
);

void main() {
  testWidgets('opens operational attendance when appointment has no session', (tester) async {
    final api = _FakeServiceSessionApi();
    await tester.pumpWidget(MaterialApp(home: ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste')));
    await tester.pump(); await tester.pump();
    expect(find.text('Atendimento'), findsOneWidget); expect(find.text('Cliente Teste'), findsOneWidget); expect(api.lookupCalled, isTrue); expect(api.openCalled, isTrue); expect(find.text('Resumo'), findsOneWidget); expect(find.text('Tempo real'), findsOneWidget);
  });

  testWidgets('resumes existing operational attendance without opening another session', (tester) async {
    final api = _FakeServiceSessionApi(existing: _session());
    await tester.pumpWidget(MaterialApp(home: ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste')));
    await tester.pump(); await tester.pump();
    expect(api.lookupCalled, isTrue); expect(api.openCalled, isFalse); expect(find.text('Resumo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Finalizar atendimento'), 200);
    expect(find.text('Finalizar atendimento'), findsOneWidget);
  });

  testWidgets('shows effective duration from persisted actual timing', (tester) async {
    final api = _FakeServiceSessionApi(existing: _session(status: ServiceSessionStatus.finished, arrivedAt: DateTime.utc(2026, 9, 12, 11, 55), serviceStartedAt: DateTime.utc(2026, 9, 12, 12, 5), serviceFinishedAt: DateTime.utc(2026, 9, 12, 12, 42), effectiveDurationMinutes: 37));
    await tester.pumpWidget(MaterialApp(home: ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste')));
    await tester.pump(); await tester.pump();
    expect(find.text('Tempo real'), findsOneWidget); expect(find.byKey(const Key('effective-duration')), findsOneWidget); expect(find.text('37 min'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Atendimento finalizado e preparado para recebimento.'), 200);
    expect(find.text('Atendimento finalizado e preparado para recebimento.'), findsOneWidget);
  });

  testWidgets('shows attendance as in progress before actual finish exists', (tester) async {
    final api = _FakeServiceSessionApi(existing: _session(status: ServiceSessionStatus.inService, arrivedAt: DateTime.utc(2026, 9, 12, 11, 55), serviceStartedAt: DateTime.utc(2026, 9, 12, 12, 5)));
    await tester.pumpWidget(MaterialApp(home: ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste')));
    await tester.pump(); await tester.pump();
    expect(find.text('Em andamento'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Finalizar atendimento'), 200);
    expect(find.text('Finalizar atendimento'), findsOneWidget);
  });

  testWidgets('does not open another session when resume lookup fails', (tester) async {
    final api = _FakeServiceSessionApi(lookupError: Exception('network failure'));
    await tester.pumpWidget(MaterialApp(home: ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste')));
    await tester.pump(); await tester.pump();
    expect(api.lookupCalled, isTrue); expect(api.openCalled, isFalse); expect(find.textContaining('Não foi possível concluir a operação.'), findsOneWidget); expect(find.text('Tentar carregar atendimento novamente'), findsOneWidget);
  });

  testWidgets('returns changed true when a newly opened attendance goes back to Agenda', (tester) async {
    final api = _FakeServiceSessionApi(); bool? routeResult;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: FilledButton(onPressed: () async { routeResult = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste'))); }, child: const Text('Abrir atendimento'))))));
    await tester.tap(find.text('Abrir atendimento')); await tester.pumpAndSettle(); expect(api.openCalled, isTrue); expect(find.text('Resumo'), findsOneWidget); await tester.tap(find.byType(BackButton)); await tester.pumpAndSettle(); expect(find.text('Abrir atendimento'), findsOneWidget); expect(routeResult, isTrue);
  });

  testWidgets('returns changed true when Android system back exits attendance', (tester) async {
    final api = _FakeServiceSessionApi(); bool? routeResult;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: FilledButton(onPressed: () async { routeResult = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ServiceSessionPage(api: api, appointmentId: 'appointment-1', clientName: 'Cliente Teste'))); }, child: const Text('Abrir atendimento'))))));
    await tester.tap(find.text('Abrir atendimento')); await tester.pumpAndSettle(); expect(api.openCalled, isTrue); expect(find.text('Resumo'), findsOneWidget); await tester.binding.handlePopRoute(); await tester.pumpAndSettle(); expect(find.text('Abrir atendimento'), findsOneWidget); expect(routeResult, isTrue);
  });
}
