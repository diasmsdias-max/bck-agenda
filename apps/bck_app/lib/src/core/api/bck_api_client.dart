import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiHealth {
  const ApiHealth({required this.status, required this.service, required this.version, required this.serverTimeUtc});
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

class BootstrapCompanyRequest {
  const BootstrapCompanyRequest({required this.companyName, this.taxId, this.companyPhone, required this.ownerName, required this.ownerUsername, required this.password, required this.deviceId, required this.deviceName, required this.platform, required this.deviceMode});
  final String companyName;
  final String? taxId;
  final String? companyPhone;
  final String ownerName;
  final String ownerUsername;
  final String password;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String deviceMode;
  Map<String, dynamic> toJson() => {'companyName': companyName, 'taxId': taxId, 'companyPhone': companyPhone, 'ownerName': ownerName, 'ownerUsername': ownerUsername, 'password': password, 'deviceId': deviceId, 'deviceName': deviceName, 'platform': platform, 'deviceMode': deviceMode};
}

class BootstrapCompanyResponse {
  const BootstrapCompanyResponse({required this.groupId, required this.userId, required this.deviceId, required this.companyName, required this.ownerName});
  final String groupId;
  final String userId;
  final String deviceId;
  final String companyName;
  final String ownerName;
  factory BootstrapCompanyResponse.fromJson(Map<String, dynamic> json) => BootstrapCompanyResponse(groupId: json['groupId'] as String, userId: json['userId'] as String, deviceId: json['deviceId'] as String, companyName: json['companyName'] as String, ownerName: json['ownerName'] as String);
}

class AuthSession {
  const AuthSession({required this.groupId, required this.userId, required this.deviceId, required this.name, required this.profile, required this.isOwner, required this.accessToken, required this.accessTokenExpiresAt, required this.refreshToken, required this.refreshTokenExpiresAt, required this.offlineLeaseExpiresAt});
  final String groupId;
  final String userId;
  final String deviceId;
  final String name;
  final String profile;
  final bool isOwner;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final DateTime offlineLeaseExpiresAt;
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(groupId: json['groupId'] as String, userId: json['userId'] as String, deviceId: json['deviceId'] as String, name: json['name'] as String, profile: json['profile'] as String, isOwner: json['isOwner'] as bool, accessToken: json['accessToken'] as String, accessTokenExpiresAt: DateTime.parse(json['accessTokenExpiresAt'] as String), refreshToken: json['refreshToken'] as String, refreshTokenExpiresAt: DateTime.parse(json['refreshTokenExpiresAt'] as String), offlineLeaseExpiresAt: DateTime.parse(json['offlineLeaseExpiresAt'] as String));
}

class BckApiClient {
  BckApiClient({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10), headers: const {'Accept': 'application/json'}));
  final Dio _dio;

  Future<ApiHealth> health() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/health');
    return ApiHealth.fromJson(response.data!);
  }

  Future<BootstrapCompanyResponse> createCompany(BootstrapCompanyRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/bootstrap/company', data: request.toJson());
    return BootstrapCompanyResponse.fromJson(response.data!);
  }

  Future<AuthSession> login({required String groupId, required String username, required String password, required String deviceId}) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/auth/login', data: {'groupId': groupId, 'username': username, 'password': password, 'deviceId': deviceId});
    return AuthSession.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/auth/refresh', data: {'refreshToken': refreshToken});
    return response.data!;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>('/api/v1/auth/logout', data: {'refreshToken': refreshToken});
  }
}
