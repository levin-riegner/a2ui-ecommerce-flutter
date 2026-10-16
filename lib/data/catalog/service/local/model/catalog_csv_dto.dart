import '../../../model/catalog_snapshot.dart';

/// Serialized catalog document supplied by a file, asset or remote transport.
/// Parsing keeps the existing strict currency, row and identity validation.
class CatalogCsvDto {
  const CatalogCsvDto({required this.csv, required this.revision});

  final String csv;
  final String revision;

  CatalogSnapshot toSnapshot() =>
      CatalogSnapshot.fromCsv(csv, revision: revision);
}
