import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'model/stylist_snapshot_dto.dart';

abstract interface class StylistSnapshotService {
  Future<StylistSnapshotDto?> read();
  Future<void> write(StylistSnapshotDto value);
}

/// Storage transport retains the existing key and serialized version-1 shape.
class SharedPreferencesStylistService implements StylistSnapshotService {
  SharedPreferencesStylistService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const storageKey = 'alder.stylist.v1';
  static const maxDocumentLength = 262144;
  final SharedPreferencesAsync _preferences;

  @override
  Future<StylistSnapshotDto?> read() async {
    final value = await _preferences.getString(storageKey);
    if (value == null) return null;
    _checkLength(value);
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Saved styling data is invalid.');
    }
    return StylistSnapshotDto(decoded);
  }

  @override
  Future<void> write(StylistSnapshotDto value) async {
    final encoded = jsonEncode(value.json);
    _checkLength(encoded);
    await _preferences.setString(storageKey, encoded);
  }

  void _checkLength(String document) {
    if (document.length > maxDocumentLength) {
      throw const FormatException('Saved styling data is too large.');
    }
  }
}
