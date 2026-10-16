import 'package:shared_preferences/shared_preferences.dart';

import '../service/local/shared_preferences_stylist_service.dart';
import 'stylist_snapshot_repository.dart';

/// Compatibility convenience. App composition injects the storage service into
/// [StylistSnapshotRepository] directly.
class LocalStylistStore extends StylistSnapshotRepository {
  LocalStylistStore({SharedPreferencesAsync? preferences})
    : super(service: SharedPreferencesStylistService(preferences: preferences));

  static const storageKey = SharedPreferencesStylistService.storageKey;
}
