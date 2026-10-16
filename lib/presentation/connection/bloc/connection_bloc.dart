import 'package:flutter_bloc/flutter_bloc.dart';

import '../service/session_connection.dart';
import '../../stylist/bloc/commerce_session.dart';
import '../../../data/stylist/model/model_settings.dart';
import 'connection_event.dart';
import 'connection_state.dart';

export 'connection_event.dart';
export 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  ConnectionBloc({required SessionConnection coordinator})
    // Public constructor injection keeps the coordinator private.
    // ignore: prefer_initializing_formals
    : _coordinator = coordinator,
      super(const ConnectionState()) {
    on<ConnectionProviderChanged>((event, emit) {
      if (_attempt == null &&
          state.canSubmit &&
          ModelSettings.providers.contains(event.provider)) {
        emit(ConnectionState(provider: event.provider));
      }
    });
    on<ConnectionConfigurationRejected>((event, emit) {
      if (_attempt == null && state.canSubmit) {
        emit(
          ConnectionState(
            provider: state.provider,
            status: ConnectionStatus.failure,
            error: ConnectionError.configuration,
          ),
        );
      }
    });
    on<ConnectionSubmitted>(_connect);
  }

  final SessionConnection _coordinator;
  ConnectionAttempt? _attempt;

  @override
  void add(ConnectionEvent event) {
    // Public event dispatch must not acquire an operation the Bloc never owned.
    if (event is ConnectionSubmitted && !identical(event.attempt, _attempt)) {
      event.attempt.cancel();
      return;
    }
    super.add(event);
  }

  /// Accepts transient secrets before adding a redacted event to the Bloc.
  /// The immediate ownership guard also rejects same-frame duplicate taps.
  void submit({
    required String model,
    required String apiKey,
    String? baseUrl,
  }) {
    if (isClosed || !state.canSubmit || _attempt != null) return;
    try {
      final settings = ModelSettings(
        provider: state.provider,
        model: model,
        apiKey: apiKey,
        baseUrl: state.provider == 'openai-compatible' ? baseUrl : null,
      );
      final attempt = _coordinator.prepare(settings);
      _attempt = attempt;
      add(ConnectionSubmitted(attempt));
    } on FormatException {
      add(const ConnectionConfigurationRejected());
    }
  }

  Future<void> _connect(
    ConnectionSubmitted event,
    Emitter<ConnectionState> emit,
  ) async {
    if (!identical(event.attempt, _attempt)) {
      event.attempt.cancel();
      return;
    }
    if (state.isBusy) return;
    emit(
      ConnectionState(
        provider: state.provider,
        status: ConnectionStatus.connecting,
      ),
    );
    try {
      final connected = await event.attempt.connect();
      if (emit.isDone || isClosed || !identical(event.attempt, _attempt)) {
        return;
      }
      if (connected) {
        emit(
          ConnectionState(
            provider: state.provider,
            status: ConnectionStatus.connected,
          ),
        );
      }
    } catch (_) {
      if (emit.isDone || isClosed || !identical(event.attempt, _attempt)) {
        return;
      }
      _attempt = null;
      emit(
        ConnectionState(
          provider: state.provider,
          status: ConnectionStatus.failure,
          error: ConnectionError.configuration,
        ),
      );
    }
  }

  /// Transfers a successful session once; the app then owns its disposal.
  CommerceSession? takeConnectedSession() {
    if (state.status != ConnectionStatus.connected) return null;
    final session = _attempt?.takeSession();
    if (session != null) _attempt = null;
    return session;
  }

  @override
  Future<void> close() {
    _attempt?.cancel();
    _attempt = null;
    return super.close();
  }
}
