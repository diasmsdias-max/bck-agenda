import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/bck_api_client.dart';
import '../../core/auth/session_store.dart';
import '../../core/config/app_config.dart';
import 'service_session_api.dart';
import 'service_session_page.dart';

Future<bool?> openServiceSessionFromAgenda(
  BuildContext context, {
  required StoredSession session,
  required AppointmentItem appointment,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: const {'Accept': 'application/json'},
  ));
  final api = ServiceSessionApi(dio: dio)
    ..setAccessToken(session.accessToken);
  return Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => ServiceSessionPage(
      api: api,
      appointmentId: appointment.id,
      clientName: appointment.clientName,
    ),
  ));
}
