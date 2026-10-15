import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'stylist_store.dart';

class LocalStylistStore implements StylistStore {
  LocalStylistStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const storageKey = 'alder.stylist.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<Map<String, Object?>?> read() async {
    final value = await _preferences.getString(storageKey);
    if (value == null) return null;
    if (value.length > 262144) {
      throw const FormatException('Saved styling data is too large.');
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Saved styling data is invalid.');
    }
    return decoded;
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    final encoded = jsonEncode(value);
    if (encoded.length > 262144) {
      throw const FormatException('Saved styling data is too large.');
    }
    await _preferences.setString(storageKey, encoded);
  }
}
