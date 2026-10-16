import '../../stylist/bloc/commerce_session.dart';
import '../../../data/stylist/model/model_settings.dart';

/// Creates a session without asking the model to generate a response.
class SessionConnection {
  const SessionConnection({required StylistConnectionFactory connect})
    // Public constructor injection keeps the factory private.
    // ignore: prefer_initializing_formals
    : _connect = connect;

  final StylistConnectionFactory _connect;

  ConnectionAttempt prepare(ModelSettings settings) =>
      ConnectionAttempt._(_connect, settings);
}

/// Owns a connection until the view explicitly accepts it.
///
/// Credentials stay private to this transient operation, outside Bloc state.
/// Cancellation clears them immediately, including while a factory is pending.
class ConnectionAttempt {
  ConnectionAttempt._(this._connect, this._settings);

  final StylistConnectionFactory _connect;
  final ModelSettings _settings;
  CommerceSession? _session;
  Future<bool>? _pending;
  bool _cancelled = false;
  bool _transferred = false;

  Future<bool> connect() {
    if (_cancelled) return Future.value(false);
    return _pending ??= _connectOnce();
  }

  Future<bool> _connectOnce() async {
    try {
      final session = await _connect(_settings);
      if (_cancelled) {
        session.dispose();
        return false;
      }
      _session = session;
      return true;
    } catch (_) {
      cancel();
      rethrow;
    }
  }

  CommerceSession? takeSession() {
    if (_cancelled || _transferred) return null;
    final session = _session;
    if (session == null) return null;
    _transferred = true;
    _session = null;
    // The accepted session owns the settings and clears its key on disposal.
    return session;
  }

  void cancel() {
    if (_cancelled || _transferred) return;
    _cancelled = true;
    _settings.clear();
    final session = _session;
    _session = null;
    session?.dispose();
  }

  @override
  String toString() => 'ConnectionAttempt(redacted)';
}
