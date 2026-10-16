import '../model/catalog_snapshot.dart';
import '../service/local/csv_catalog_service.dart';

/// Maps a serialized catalog service into the host's complete snapshot port.
class CsvCatalogSource implements CatalogSource {
  CsvCatalogSource({
    required Future<String> Function() readText,
    String revision = bundledCatalogRevision,
  }) : _service = CsvCatalogService(readText: readText, revision: revision);

  const CsvCatalogSource.service(CsvCatalogService service)
    : _service = service;

  final CsvCatalogService _service;

  @override
  Future<CatalogSnapshot> load() async => (await _service.read()).toSnapshot();
}
