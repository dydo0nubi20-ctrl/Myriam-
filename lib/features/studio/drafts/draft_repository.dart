library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../entities/project.dart';

part 'draft_repository.g.dart';

class DraftProjects extends Table {
  TextColumn get id => text()();
  TextColumn get caption => text().withDefault(const Constant(''))();
  TextColumn get json => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get coverPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DraftProjects])
class StudioDraftDatabase extends _$StudioDraftDatabase {
  StudioDraftDatabase(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'setrize_drafts.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Local-only draft store. A draft is just a [StudioProject] frozen to
/// JSON — the same model the editor mutates in memory, so loading a
/// draft back drops the user into exactly the project they left, undo
/// history aside (history intentionally doesn't persist across app
/// restarts, same as every mainstream editor).
class DraftRepository {
  DraftRepository() : _db = StudioDraftDatabase(_openConnection());

  final StudioDraftDatabase _db;

  Future<void> initialize() async {
    // Touch the database once on startup so the first real save isn't
    // the one paying for file creation + migration.
    await _db.select(_db.draftProjects).get();
  }

  Future<void> save(StudioProject project) async {
    await _db.into(_db.draftProjects).insertOnConflictUpdate(
          DraftProjectsCompanion.insert(
            id: project.id,
            caption: Value(project.caption),
            json: jsonEncode(project.toJson()),
            createdAt: project.createdAt,
            updatedAt: Value(DateTime.now()),
            coverPath: Value(project.coverPath),
          ),
        );
  }

  Future<List<StudioProject>> listAll() async {
    final rows = await (_db.select(_db.draftProjects)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_decode).whereType<StudioProject>().toList();
  }

  Future<StudioProject?> load(String id) async {
    final row = await (_db.select(_db.draftProjects)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.draftProjects)..where((t) => t.id.equals(id))).go();
  }

  StudioProject? _decode(DraftProject row) {
    try {
      return StudioProject.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _db.close();
}
