import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

class PendingServiceSessionCommand {
  const PendingServiceSessionCommand({
    required this.eventId,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.occurredAt,
    required this.idempotencyKey,
  });

  final String eventId;
  final String entityId;
  final String operation;
  final String payloadJson;
  final DateTime occurredAt;
  final String idempotencyKey;
}

class ServiceSessionCommandQueue {
  ServiceSessionCommandQueue(
    this._database, {
    required String groupId,
    required String userId,
  }) : _entityScope = '$entityTypePrefix:$groupId:$userId';

  static const entityTypePrefix = 'SERVICE_SESSION';
  static const openOperation = 'OPEN';
  static const addItemOperation = 'ADD_ITEM';
  static const finishOperation = 'FINISH';

  final AppDatabase _database;
  final String _entityScope;

  Future<void> enqueue({
    required String eventId,
    required String entityId,
    required String operation,
    required String payloadJson,
    required DateTime occurredAt,
    required String idempotencyKey,
  }) async {
    await _database.into(_database.syncQueue).insert(
      SyncQueueCompanion.insert(
        eventId: eventId,
        entityType: _entityScope,
        entityId: entityId,
        operation: operation,
        payloadJson: payloadJson,
        occurredAt: occurredAt.toUtc(),
        idempotencyKey: idempotencyKey,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<PendingServiceSessionCommand>> pending() async {
    final query = _database.select(_database.syncQueue)
      ..where((row) =>
          row.entityType.equals(_entityScope) & row.status.equals('PENDING'))
      ..orderBy([
        (row) => OrderingTerm.asc(row.occurredAt),
        (row) => OrderingTerm.asc(row.eventId),
      ]);
    final rows = await query.get();
    return rows
        .map((row) => PendingServiceSessionCommand(
              eventId: row.eventId,
              entityId: row.entityId,
              operation: row.operation,
              payloadJson: row.payloadJson,
              occurredAt: row.occurredAt,
              idempotencyKey: row.idempotencyKey,
            ))
        .toList(growable: false);
  }

  Future<void> complete(String eventId) async {
    await (_database.delete(_database.syncQueue)
          ..where((row) => row.eventId.equals(eventId)))
        .go();
  }

  Future<void> fail(String eventId) async {
    await (_database.update(_database.syncQueue)
          ..where((row) => row.eventId.equals(eventId)))
        .write(const SyncQueueCompanion(status: Value('FAILED')));
  }
}
