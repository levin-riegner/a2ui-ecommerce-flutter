import '../model/stylist_snapshot.dart';
import '../service/local/model/stylist_snapshot_dto.dart';
import '../service/local/shared_preferences_stylist_service.dart';
import 'stylist_store.dart';

/// Maps storage DTOs to immutable domain snapshots while retaining the runtime's
/// existing map port. This layer never decides whether catalog facts are valid.
class StylistSnapshotRepository implements StylistStore {
  const StylistSnapshotRepository({required StylistSnapshotService service})
    // Public injection preserves a private service field.
    // ignore: prefer_initializing_formals
    : _service = service;

  final StylistSnapshotService _service;

  Future<StylistSnapshot?> readSnapshot() async =>
      (await _service.read())?.toSnapshot();

  Future<void> writeSnapshot(StylistSnapshot value) =>
      _service.write(StylistSnapshotDto(value.toJson()));

  @override
  Future<Map<String, Object?>?> read() async =>
      (await readSnapshot())?.toJson();

  @override
  Future<void> write(Map<String, Object?> value) =>
      writeSnapshot(StylistSnapshot.fromJson(value));
}
