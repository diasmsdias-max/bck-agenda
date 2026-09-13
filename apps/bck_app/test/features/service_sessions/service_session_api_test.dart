import 'dart:convert';

import 'package:bck_agenda/src/features/service_sessions/service_session_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends bearer authentication on all service-session operations', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.httpClientAdapter = _RecordingAdapter(requests);
    final api = ServiceSessionApi(dio: dio)..setAccessToken('access-token');

    await api.getByAppointment('appointment-1');
    await api.open(appointmentId: 'appointment-1');
    await api.get('session-1');
    await api.addItem(
      'session-1',
      itemType: 'PRODUCT',
      name: 'Produto extra',
      quantity: 1,
      unitPrice: 10,
    );
    await api.finish('session-1');

    expect(requests, hasLength(5));
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer access-token');
    }
  });

  test('sends idempotency key only on mutable commands and preserves explicit key', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.httpClientAdapter = _RecordingAdapter(requests);
    final api = ServiceSessionApi(dio: dio)..setAccessToken('access-token');

    await api.getByAppointment('appointment-1');
    await api.get('session-1');
    await api.open(appointmentId: 'appointment-1', idempotencyKey: 'open-key-123');
    await api.addItem(
      'session-1',
      itemType: 'PRODUCT',
      name: 'Produto extra',
      quantity: 1,
      unitPrice: 10,
      idempotencyKey: 'item-key-123',
    );
    await api.finish('session-1', idempotencyKey: 'finish-key-123');

    expect(requests[0].headers['Idempotency-Key'], isNull);
    expect(requests[1].headers['Idempotency-Key'], isNull);
    expect(requests[2].headers['Idempotency-Key'], 'open-key-123');
    expect(requests[3].headers['Idempotency-Key'], 'item-key-123');
    expect(requests[4].headers['Idempotency-Key'], 'finish-key-123');
  });

  test('generates valid distinct idempotency keys', () {
    final api = ServiceSessionApi(dio: Dio());
    final first = api.newIdempotencyKey();
    final second = api.newIdempotencyKey();

    expect(first.length, inInclusiveRange(8, 128));
    expect(second.length, inInclusiveRange(8, 128));
    expect(second, isNot(first));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.path;
    if (path.contains('/items')) {
      return _json(_itemJson);
    }
    return _json(_sessionJson);
  }

  ResponseBody _json(Map<String, Object?> body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

final _sessionJson = <String, Object?>{
  'id': 'session-1',
  'appointmentId': 'appointment-1',
  'professionalUserId': 'professional-1',
  'clientName': 'Cliente Teste',
  'status': 'OPEN',
  'subtotal': 10,
  'discountTotal': 0,
  'total': 10,
  'createdAt': '2026-09-13T00:00:00Z',
};

final _itemJson = <String, Object?>{
  'id': 'item-1',
  'itemType': 'PRODUCT',
  'name': 'Produto extra',
  'quantity': 1,
  'unitPrice': 10,
  'discountAmount': 0,
  'lineSubtotal': 10,
  'lineTotal': 10,
};
