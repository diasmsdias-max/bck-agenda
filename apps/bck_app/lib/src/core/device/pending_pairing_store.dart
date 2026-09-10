import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PendingPairing {
  const PendingPairing({required this.groupId, required this.deviceId});

  final String groupId;
  final String deviceId;
}

class PendingPairingStore {
  PendingPairingStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _groupIdKey = 'pairing.pending.groupId';
  static const _deviceIdKey = 'pairing.pending.deviceId';

  final FlutterSecureStorage _storage;

  Future<void> save({required String groupId, required String deviceId}) async {
    await _storage.write(key: _groupIdKey, value: groupId);
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<PendingPairing?> read() async {
    final groupId = await _storage.read(key: _groupIdKey);
    final deviceId = await _storage.read(key: _deviceIdKey);
    if (groupId == null || groupId.isEmpty || deviceId == null || deviceId.isEmpty) {
      return null;
    }
    return PendingPairing(groupId: groupId, deviceId: deviceId);
  }

  Future<void> clear() async {
    await _storage.delete(key: _groupIdKey);
    await _storage.delete(key: _deviceIdKey);
  }
}
