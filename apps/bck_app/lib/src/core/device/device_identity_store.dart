import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Identidade estável da instalação do BCK Agenda.
///
/// Não pertence à sessão autenticada e, por isso, não deve ser apagada em
/// logout ou limpeza de credenciais. O mesmo UUID é reutilizado em bootstrap,
/// pareamento e tentativas posteriores do fluxo de conexão.
class DeviceIdentityStore {
  DeviceIdentityStore({FlutterSecureStorage? storage, Uuid? uuid})
      : _storage = storage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  static const _deviceIdKey = 'installation.deviceId';

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final created = _uuid.v4();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }
}
