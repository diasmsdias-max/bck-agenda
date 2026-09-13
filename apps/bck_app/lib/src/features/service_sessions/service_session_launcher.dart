import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import '../../core/config/app_config.dart';
import '../../core/database/app_database.dart';
import 'service_session_api.dart';
import 'service_session_command_queue.dart';
import 'service_session_page.dart';

Future<bool?> openServiceSessionFromAgenda(
  BuildContext context, {
  required StoredSession session,
  required AppointmentItem appointment,
}) async {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: const {'Accept': 'application/json'},
  ));
  final database = AppDatabase();
  final api = ServiceSessionApi(
    dio: dio,
    commandQueue: ServiceSessionCommandQueue(
      database,
      groupId: session.groupId,
      userId: session.userId,
    ),
    now: session.estimatedServerNow,
  )
    ..setAccessToken(session.accessToken);
  try {
    return await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ServiceSessionPage(
        api: api,
        appointmentId: appointment.id,
        clientName: appointment.clientName,
      ),
    ));
  } finally {
    await database.close();
  }
}
