import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_factory_native.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';

/// On-device SQLite store with two jobs:
///
///  * a read-through cache so the app opens and an audit can be reviewed
///    with no connection at all;
///  * a durable outbox so every write survives the app being killed and
///    is replayed exactly once when connectivity returns.
///
/// Nothing confidential beyond what the user is already authorised to see
/// is stored, and the cache is cleared on sign-out.
class LocalStore {
  LocalStore._(this._db, [this._owner = ''])
      : _ready = _owner.isEmpty
            ? Future<void>.value()
            : _prepareSharedScope(_db, _owner);

  final Database _db;
  final String _owner;
  final Future<void> _ready;
  static const _uuid = Uuid();

  /// Cache and pending writes belong to one account on one backend. Legacy
  /// unowned rows stay preserved until their owner can be established.
  LocalStore scopedTo(String owner) => LocalStore._(_db, owner);

  String _key(String key) => _owner.isEmpty ? key : jsonEncode([_owner, key]);

  static Future<LocalStore> open({String? path}) async {
    final factory = localDatabaseFactory;
    final databasePath =
        path ?? p.join(await factory.getDatabasesPath(), 'kafaa_local.db');
    final db = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
          create table cache (
            key        text primary key,
            owner      text not null default '',
            payload    text not null,
            updated_at integer not null
          )
        ''');
          await db.execute('''
          create table outbox (
            id          text primary key,
            owner       text not null default '',
            kind        text not null,
            payload     text not null,
            created_at  integer not null,
            attempts    integer not null default 0,
            last_error  text
          )
        ''');
          await db.execute('create index outbox_created on outbox(created_at)');
          await _createScopeVersions(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute(
                "alter table cache add column owner text not null default ''");
            await db.execute(
                "alter table outbox add column owner text not null default ''");
          }
          if (oldVersion < 3) await _createScopeVersions(db);
        },
      ),
    );
    return LocalStore._(db);
  }

  static Future<void> _createScopeVersions(Database db) => db.execute('''
    create table scope_versions (
      owner text primary key,
      version integer not null
    )
  ''');

  /// The shared-only rollout retires the pre-release mock cache and queue
  /// once per project/account. Later offline work survives relaunch/sign-out.
  static Future<void> _prepareSharedScope(Database db, String owner) =>
      db.transaction((txn) async {
        final versions = await txn
            .query('scope_versions', where: 'owner = ?', whereArgs: [owner]);
        if (versions.isNotEmpty) return;
        await txn.delete('cache', where: 'owner = ?', whereArgs: [owner]);
        await txn.delete('outbox', where: 'owner = ?', whereArgs: [owner]);
        await txn.insert('scope_versions', {'owner': owner, 'version': 1});
      });

  // -------------------------------------------------------------------
  // Cache
  // -------------------------------------------------------------------

  Future<void> putCache(String key, Object payload) async {
    await _ready;
    await _db.insert(
      'cache',
      {
        'key': _key(key),
        'owner': _owner,
        'payload': jsonEncode(payload),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<T?> readCache<T>(String key) async {
    await _ready;
    final rows = await _db.query('cache',
        where: 'key = ? and owner = ?', whereArgs: [_key(key), _owner]);
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['payload'] as String) as T;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> cacheAge(String key) async {
    await _ready;
    final rows = await _db.query(
      'cache',
      columns: ['updated_at'],
      where: 'key = ? and owner = ?',
      whereArgs: [_key(key), _owner],
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['updated_at'] as int);
  }

  Future<void> clearCache() async {
    await _ready;
    await _db.delete('cache', where: 'owner = ?', whereArgs: [_owner]);
  }

  // -------------------------------------------------------------------
  // Outbox
  // -------------------------------------------------------------------

  /// Queues a mutation. [dedupeKey] collapses repeated edits to the same
  /// field — scoring one criterion five times leaves one pending write,
  /// not five.
  Future<String> enqueue(
    OutboxKind kind,
    Map<String, dynamic> payload, {
    String? dedupeKey,
  }) async {
    await _ready;
    final id = _key(dedupeKey ?? _uuid.v4());
    await _db.insert(
      'outbox',
      {
        'id': id,
        'owner': _owner,
        'kind': kind.name,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
        'last_error': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<String> enqueueWithCache(OutboxKind kind, Map<String, dynamic> payload,
      {String? dedupeKey,
      required String cacheKey,
      required Object cacheValue}) async {
    await _ready;
    final id = _key(dedupeKey ?? _uuid.v4());
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.insert(
          'cache',
          {
            'key': _key(cacheKey),
            'owner': _owner,
            'payload': jsonEncode(cacheValue),
            'updated_at': now
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert(
          'outbox',
          {
            'id': id,
            'owner': _owner,
            'kind': kind.name,
            'payload': jsonEncode(payload),
            'created_at': now,
            'attempts': 0,
            'last_error': null
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return id;
  }

  Future<List<OutboxEntry>> pending(
      {int? limit, bool includeExhausted = true}) async {
    await _ready;
    final rows = await _db.query(
      'outbox',
      where: 'owner = ?${includeExhausted ? '' : ' and attempts < 8'}',
      whereArgs: [_owner],
      orderBy: 'created_at asc, rowid asc',
      limit: limit,
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  Future<int> pendingCount() async {
    await _ready;
    final result = await _db
        .rawQuery('select count(*) as c from outbox where owner = ?', [_owner]);
    return (result.first['c'] as int?) ?? 0;
  }

  /// A newer edit may replace this key while the network request is in flight.
  /// Only acknowledge the exact snapshot that was sent.
  Future<void> remove(String id, {OutboxEntry? expected}) async {
    await _ready;
    await _db.delete(
      'outbox',
      where: expected == null
          ? 'id = ? and owner = ?'
          : 'id = ? and owner = ? and payload = ? and created_at = ?',
      whereArgs: [
        id,
        _owner,
        if (expected != null) ...[
          jsonEncode(expected.payload),
          expected.createdAt.millisecondsSinceEpoch,
        ],
      ],
    );
  }

  Future<void> markFailed(String id, String error,
      {OutboxEntry? expected, bool permanent = false}) async {
    await _ready;
    await _db.rawUpdate(
      'update outbox set attempts = ${permanent ? 8 : 'attempts + 1'}, last_error = ? where id = ? and owner = ?'
      '${expected == null ? '' : ' and payload = ? and created_at = ?'}',
      [
        error,
        id,
        _owner,
        if (expected != null) ...[
          jsonEncode(expected.payload),
          expected.createdAt.millisecondsSinceEpoch,
        ],
      ],
    );
  }

  Future<void> replacePending(
      OutboxEntry entry, Map<String, dynamic> payload) async {
    await _ready;
    await _db.update('outbox',
        {'payload': jsonEncode(payload), 'attempts': 0, 'last_error': null},
        where: 'id = ? and owner = ? and payload = ?',
        whereArgs: [entry.id, _owner, jsonEncode(entry.payload)]);
  }

  Future<void> clearOutbox() async {
    await _ready;
    await _db.delete('outbox', where: 'owner = ?', whereArgs: [_owner]);
  }

  Future<void> close() async {
    await _ready;
    await _db.close();
  }

  Future<void> wipe() async {
    await clearCache();
    await clearOutbox();
  }
}

enum OutboxKind {
  auditTeamUpsert,
  auditTeamRemove,
  evidenceReviewAppend,
  selfAuditCreate,
  selfResponseUpsert,
  selfEvidenceUpload,
  ncrNoteAppend,
  ncrEvidenceUpload,
  centerSave,
  auditMessage,
  assessmentJoin,
  responseUpsert,
  auditUpdate,
  evidenceUpload,
  sampleInsert,
  ncrUpdate,
}

class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  final String id;
  final OutboxKind kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Stop retrying after repeated hard failures so a single poisoned
  /// entry cannot block the queue forever.
  bool get isExhausted => attempts >= 8;

  factory OutboxEntry.fromRow(Map<String, Object?> row) => OutboxEntry(
        id: row['id'] as String,
        kind: OutboxKind.values.firstWhere(
          (k) => k.name == row['kind'],
        ),
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        attempts: row['attempts'] as int? ?? 0,
        lastError: row['last_error'] as String?,
      );
}

/// Overridden in main() once the database is open.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('LocalStore must be overridden'),
);
