import '../../model/catalog_snapshot.dart';
import 'model/catalog_csv_dto.dart';

/// Reads the serialized source; repository adapters map it to domain values.
class CsvCatalogService {
  const CsvCatalogService({
    required this.readText,
    this.revision = bundledCatalogRevision,
  });

  final Future<String> Function() readText;
  final String revision;

  Future<CatalogCsvDto> read() async =>
      CatalogCsvDto(csv: await readText(), revision: revision);
}
