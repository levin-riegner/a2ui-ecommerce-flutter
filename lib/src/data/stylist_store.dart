/// Stores only styling state and demo catalog IDs. Provider credentials and
/// conversation/model payloads never enter this contract.
abstract interface class StylistStore {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> value);
}
