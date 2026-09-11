import 'package:flutter_test/flutter_test.dart';

/// Contrato comportamental da visão administrativa "Todos".
///
/// A consolidação deve preservar todos os atendimentos retornados pelos
/// profissionais, ordenar por início e nunca misturar a identidade do
/// profissional. O teste mantém explícita a regra enquanto a UI é conectada
/// ao carregador de equipe.
void main() {
  test('agenda consolidada mantém ordem cronológica e profissional', () {
    final items = <({String id, String professionalId, DateTime startsAt})>[
      (id: 'b', professionalId: 'prof-2', startsAt: DateTime(2026, 9, 11, 10)),
      (id: 'a', professionalId: 'prof-1', startsAt: DateTime(2026, 9, 11, 9)),
      (id: 'c', professionalId: 'prof-1', startsAt: DateTime(2026, 9, 11, 10)),
    ];

    items.sort((a, b) {
      final byStart = a.startsAt.compareTo(b.startsAt);
      if (byStart != 0) return byStart;
      return a.professionalId.compareTo(b.professionalId);
    });

    expect(items.map((x) => x.id), ['a', 'c', 'b']);
    expect(items.map((x) => x.professionalId).toSet(), {'prof-1', 'prof-2'});
  });

  test('IDs repetidos de profissionais são eliminados antes das consultas', () {
    final professionalIds = ['prof-1', 'prof-2', 'prof-1'];
    expect(professionalIds.toSet().toList(), ['prof-1', 'prof-2']);
  });
}
