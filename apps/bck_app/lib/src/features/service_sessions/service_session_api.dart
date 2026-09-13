import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import 'service_session_command_queue.dart';
import 'service_session_models.dart';

class ServiceSessionApi {
  ServiceSessionApi({
    Dio? dio,
    ServiceSessionCommandQueue? commandQueue,
    DateTime Function()? now,
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {'Accept': 'application/json'},
            )),
        _commandQueue = commandQueue,
        _now = now ?? DateTime.now;

  final Dio _dio;
  final ServiceSessionCommandQueue? _commandQueue;
  final DateTime Function() _now;
  final Random _random = Random.secure();
  String? _accessToken;
  bool _synchronizing = false;

  void setAccessToken(String? token) => _accessToken = token;

  Options _authorized({String? idempotencyKey}) => Options(headers: {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      });

  String newIdempotencyKey() {
    final timestamp = _now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'bck-$timestamp-$entropy';
  }

  Future<ServiceSession> open({
    required String appointmentId,
    String? notes,
    String? idempotencyKey,
    DateTime? occurredAt,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey();
    final eventTime = (occurredAt ?? _now()).toUtc();
    final payload = <String, dynamic>{
      'appointmentId': appointmentId,
      'notes': notes,
      'occurredAt': eventTime.toIso8601String(),
    };
    final response = await _postQueued(
      path: '/api/v1/service-sessions',
      entityId: appointmentId,
      operation: ServiceSessionCommandQueue.openOperation,
      payload: payload,
      occurredAt: eventTime,
      idempotencyKey: key,
    );
    return ServiceSession.fromJson(response.data!);
  }

  Future<ServiceSession> get(String id) async {
    await synchronizePending();
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/service-sessions/$id',
      options: _authorized(),
    );
    return ServiceSession.fromJson(response.data!);
  }

  Future<List<ServiceSessionHistory>> getHistory(String id) async {
    await synchronizePending();
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/service-sessions/$id/history',
      options: _authorized(),
    );
    return response.data!
        .map((item) => ServiceSessionHistory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<ServiceSession> updateNotes(String id, String? notes) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/service-sessions/$id/notes',
      data: {'notes': notes},
      options: _authorized(),
    );
    return ServiceSession.fromJson(response.data!);
  }

  Future<ServiceSession?> getByAppointment(String appointmentId) async {
    await synchronizePending();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/appointments/$appointmentId/service-session',
        options: _authorized(),
      );
      return ServiceSession.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ServiceSessionItem> addItem(
    String sessionId, {
    required String itemType,
    String? serviceId,
    String? sourceItemId,
    required String name,
    required double quantity,
    required double unitPrice,
    double discountAmount = 0,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey();
    final eventTime = _now().toUtc();
    final payload = <String, dynamic>{
      'itemType': itemType,
      'serviceId': serviceId,
      'sourceItemId': sourceItemId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discountAmount': discountAmount,
    };
    final response = await _postQueued(
      path: '/api/v1/service-sessions/$sessionId/items',
      entityId: sessionId,
      operation: ServiceSessionCommandQueue.addItemOperation,
      payload: payload,
      occurredAt: eventTime,
      idempotencyKey: key,
    );
    return ServiceSessionItem.fromJson(response.data!);
  }

  Future<ServiceSession> finish(
    String sessionId, {
    String? notes,
    String? idempotencyKey,
    DateTime? occurredAt,
  }) async {
    final key = idempotencyKey ?? newIdempotencyKey();
    final eventTime = (occurredAt ?? _now()).toUtc();
    final payload = <String, dynamic>{
      'notes': notes,
      'occurredAt': eventTime.toIso8601String(),
    };
    final response = await _postQueued(
      path: '/api/v1/service-sessions/$sessionId/finish',
      entityId: sessionId,
      operation: ServiceSessionCommandQueue.finishOperation,
      payload: payload,
      occurredAt: eventTime,
      idempotencyKey: key,
    );
    return ServiceSession.fromJson(response.data!);
  }

  Future<Response<Map<String, dynamic>>> _postQueued({
    required String path,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    required DateTime occurredAt,
    required String idempotencyKey,
  }) async {
    final queue = _commandQueue;
    if (queue != null) {
      await queue.enqueue(
        eventId: idempotencyKey,
        entityId: entityId,
        operation: operation,
        payloadJson: jsonEncode(payload),
        occurredAt: occurredAt,
        idempotencyKey: idempotencyKey,
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
        options: _authorized(idempotencyKey: idempotencyKey),
      );
      await queue?.complete(idempotencyKey);
      return response;
    } on DioException catch (error) {
      if (_isPermanentClientFailure(error)) {
        await queue?.fail(idempotencyKey);
      }
      rethrow;
    }
  }

  Future<void> synchronizePending() async {
    final queue = _commandQueue;
    if (queue == null || _synchronizing) return;
    _synchronizing = true;
    try {
      for (final command in await queue.pending()) {
        try {
          final payload = Map<String, dynamic>.from(
            jsonDecode(command.payloadJson) as Map,
          );
          await _dio.post<Map<String, dynamic>>(
            _pathFor(command),
            data: payload,
            options: _authorized(idempotencyKey: command.idempotencyKey),
          );
          await queue.complete(command.eventId);
        } on DioException catch (error) {
          if (_isPermanentClientFailure(error)) {
            await queue.fail(command.eventId);
            continue;
          }
          break;
        } on FormatException {
          await queue.fail(command.eventId);
        }
      }
    } finally {
      _synchronizing = false;
    }
  }

  String _pathFor(PendingServiceSessionCommand command) =>
      switch (command.operation) {
        ServiceSessionCommandQueue.openOperation =>
          '/api/v1/service-sessions',
        ServiceSessionCommandQueue.addItemOperation =>
          '/api/v1/service-sessions/${command.entityId}/items',
        ServiceSessionCommandQueue.finishOperation =>
          '/api/v1/service-sessions/${command.entityId}/finish',
        _ => throw const FormatException(
            'Unsupported service-session command',
          ),
      };

  static bool _isPermanentClientFailure(DioException error) {
    final status = error.response?.statusCode;
    return status == 400 || status == 403 || status == 404 || status == 422;
  }
}
