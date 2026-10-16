import '../../../model/stylist_snapshot.dart';

/// Serialized storage document. Domain construction happens at the repository.
class StylistSnapshotDto {
  const StylistSnapshotDto(this.json);

  final Map<String, Object?> json;

  StylistSnapshot toSnapshot() => StylistSnapshot.fromJson(json);
}
