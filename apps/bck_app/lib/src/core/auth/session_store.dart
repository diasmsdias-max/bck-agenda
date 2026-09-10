import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/bck_api_client.dart';

class StoredSession {
  const StoredSession({required this.groupId, required this.userId, required this.deviceId, required this.name, required this.profile, required this.isOwner, required this.accessToken, required this.accessTokenExpiresAt, required this.refreshToken, required this.refreshTokenExpiresAt, required this.offlineLeaseExpiresAt});
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

  bool get canOperateOffline => DateTime.now().toUtc().isBefore(offlineLeaseExpiresAt.toUtc());
}

class SessionStore {
  SessionStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static const _groupId = 'auth.groupId';
  static const _userId = 'auth.userId';
  static const _deviceId = 'auth.deviceId';
  static const _name = 'auth.name';
  static const _profile = 'auth.profile';
  static const _isOwner = 'auth.isOwner';
  static const _accessToken = 'auth.accessToken';
  static const _accessExpires = 'auth.accessExpires';
  static const _refreshToken = 'auth.refreshToken';
  static const _refreshExpires = 'auth.refreshExpires';
  static const _offlineLeaseExpires = 'auth.offlineLeaseExpires';

  Future<void> save(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _groupId, value: session.groupId),
      _storage.write(key: _userId, value: session.userId),
      _storage.write(key: _deviceId, value: session.deviceId),
      _storage.write(key: _name, value: session.name),
      _storage.write(key: _profile, value: session.profile),
      _storage.write(key: _isOwner, value: session.isOwner.toString()),
      _storage.write(key: _accessToken, value: session.accessToken),
      _storage.write(key: _accessExpires, value: session.accessTokenExpiresAt.toUtc().toIso8601String()),
      _storage.write(key: _refreshToken, value: session.refreshToken),
      _storage.write(key: _refreshExpires, value: session.refreshTokenExpiresAt.toUtc().toIso8601String()),
      _storage.write(key: _offlineLeaseExpires, value: session.offlineLeaseExpiresAt.toUtc().toIso8601String()),
    ]);
  }

  Future<StoredSession?> read() async {
    final values = await Future.wait([
      _storage.read(key: _groupId), _storage.read(key: _userId), _storage.read(key: _deviceId), _storage.read(key: _name), _storage.read(key: _profile), _storage.read(key: _isOwner), _storage.read(key: _accessToken), _storage.read(key: _accessExpires), _storage.read(key: _refreshToken), _storage.read(key: _refreshExpires), _storage.read(key: _offlineLeaseExpires),
    ]);
    if (values.any((value) => value == null)) return null;
    try {
      return StoredSession(groupId: values[0]!, userId: values[1]!, deviceId: values[2]!, name: values[3]!, profile: values[4]!, isOwner: values[5] == 'true', accessToken: values[6]!, accessTokenExpiresAt: DateTime.parse(values[7]!), refreshToken: values[8]!, refreshTokenExpiresAt: DateTime.parse(values[9]!), offlineLeaseExpiresAt: DateTime.parse(values[10]!));
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.deleteAll();
}
