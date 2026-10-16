import 'dart:convert';

import 'package:a2ui_flutter_commerce/data/stylist/repository/stylist_store.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class MemoryStylistStore implements StylistStore {
  String? encoded;
  Future<void> Function()? beforeWrite;
  @override
  Future<Map<String, Object?>?> read() async => encoded == null
      ? null
      : Map<String, Object?>.from(jsonDecode(encoded!) as Map);
  @override
  Future<void> write(Map<String, Object?> value) async {
    await beforeWrite?.call();
    encoded = jsonEncode(value);
  }
}

final class MemoryPreferencePlatform extends SharedPreferencesAsyncPlatform {
  final values = <String, String>{};
  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async => values[key];
  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
