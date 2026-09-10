import 'package:bck_app/src/core/device/device_identity_store.dart';
import 'package:bck_app/src/core/device/pending_pairing_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('DeviceIdentityStore cria e reutiliza o mesmo deviceId', () async {
    const storage = FlutterSecureStorage();
    final store = DeviceIdentityStore(storage: storage, uuid: const Uuid());

    final first = await store.getOrCreateDeviceId();
    final second = await store.getOrCreateDeviceId();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(await storage.read(key: 'installation.deviceId'), first);
  });

  test('DeviceIdentityStore reutiliza identidade já persistida', () async {
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'installation.deviceId',
      value: 'device-estavel-123',
    );

    final store = DeviceIdentityStore(storage: storage, uuid: const Uuid());

    expect(await store.getOrCreateDeviceId(), 'device-estavel-123');
  });

  test('PendingPairingStore salva e recupera groupId e deviceId', () async {
    const storage = FlutterSecureStorage();
    final store = PendingPairingStore(storage: storage);

    await store.save(groupId: 'group-a', deviceId: 'device-a');
    final pending = await store.read();

    expect(pending, isNotNull);
    expect(pending!.groupId, 'group-a');
    expect(pending.deviceId, 'device-a');
  });

  test('PendingPairingStore clear remove estado pendente', () async {
    const storage = FlutterSecureStorage();
    final store = PendingPairingStore(storage: storage);

    await store.save(groupId: 'group-a', deviceId: 'device-a');
    await store.clear();

    expect(await store.read(), isNull);
  });

  test('PendingPairingStore ignora estado incompleto', () async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'pairing.pending.groupId', value: 'group-a');

    final store = PendingPairingStore(storage: storage);

    expect(await store.read(), isNull);
  });
}
