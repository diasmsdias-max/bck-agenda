import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session_store.dart';
import '../../core/config/app_config.dart';
import '../agenda/agenda_models.dart';
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
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    },
  ));
  final api = ServiceSessionApi(dio: dio);
  return Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => ServiceSessionPage(
      api: api,
      appointmentId: appointment.id,
      clientName: appointment.clientName,
    ),
  ));
}
