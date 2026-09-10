import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiHealth {
  const ApiHealth({
    required this.status,
    required this.service,
    required this.version,
    required this.serverTimeUtc,
  });

  final String status;
  final String service;
  final String version;
  final DateTime serverTimeUtc;

  factory ApiHealth.fromJson(Map<String, dynamic> json) => ApiHealth(
        status: json['status'] as String,
        service: json['service'] as String,
        version: json['version'] as String,
        serverTimeUtc: DateTime.parse(json['serverTimeUtc'] as String),
      );
}

class BckApiClient {
  BckApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {'Accept': 'application/json'},
            ));

  final Dio _dio;

  Future<ApiHealth> health() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/health');
    return ApiHealth.fromJson(response.data!);
  }
}
