import 'dart:async';

import 'package:a2ui_flutter_commerce/presentation/connection/service/session_connection.dart';
import 'package:a2ui_flutter_commerce/presentation/connection/bloc/connection_bloc.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_session.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/model_settings.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends CommerceSession {
  int disposals = 0;

  @override
  bool get hasStarted => false;
  @override
  DemoJourney? get activeJourney => null;
  @override
  Future<void> startJourney(DemoJourney journey) async {}
  @override
  Future<void> sendMessage(String message) async {}
  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

class _RecordingConnectionBloc extends ConnectionBloc {
  _RecordingConnectionBloc({required super.coordinator});

  ConnectionSubmitted? submitted;

  @override
  void onEvent(ConnectionEvent event) {
    if (event is ConnectionSubmitted) submitted = event;
    super.onEvent(event);
  }
}

Future<ConnectionState> status(
  ConnectionBloc bloc,
  ConnectionStatus expected,
) => bloc.stream.firstWhere((state) => state.status == expected);

void main() {
  test('immutable presentation state compares by value', () {
    expect(const ConnectionState(), const ConnectionState());
    expect(
      const ConnectionState(provider: 'openai'),
      isNot(const ConnectionState()),
    );
    expect(
      const ConnectionState(status: ConnectionStatus.connecting),
      isNot(const ConnectionState()),
    );
  });

  test(
    'an unowned submission is cancelled without invoking its factory',
    () async {
      var calls = 0;
      final coordinator = SessionConnection(
        connect: (_) async {
          calls++;
          return _Session();
        },
      );
      final settings = ModelSettings(
        provider: 'googleai',
        model: 'test-model',
        apiKey: 'unowned-key',
      );
      final bloc = ConnectionBloc(coordinator: coordinator);
      bloc.add(ConnectionSubmitted(coordinator.prepare(settings)));
      await bloc.close();
      expect(calls, 0);
      expect(settings.apiKey, isEmpty);
    },
  );

  test(
    'replaying an owned event cannot create duplicate connections',
    () async {
      final pending = Completer<CommerceSession>();
      final session = _Session();
      var calls = 0;
      final bloc = _RecordingConnectionBloc(
        coordinator: SessionConnection(
          connect: (_) {
            calls++;
            return pending.future;
          },
        ),
      );
      final started = status(bloc, ConnectionStatus.connecting);
      bloc.submit(model: 'test-model', apiKey: 'first-key');
      bloc.add(bloc.submitted!);
      await started;
      expect(calls, 1);
      final closing = bloc.close();
      pending.complete(session);
      await closing;
      expect(session.disposals, 1);
    },
  );

  test('accepted session transfers once and keeps its live key', () async {
    final session = _Session();
    ModelSettings? supplied;
    final bloc = ConnectionBloc(
      coordinator: SessionConnection(
        connect: (settings) async {
          supplied = settings;
          return session;
        },
      ),
    );
    final ready = status(bloc, ConnectionStatus.connected);
    bloc.submit(model: 'test-model', apiKey: 'private-key');
    await ready;
    expect(bloc.takeConnectedSession(), same(session));
    expect(bloc.takeConnectedSession(), isNull);
    await bloc.close();
    expect(session.disposals, 0);
    expect(supplied!.apiKey, 'private-key');
    supplied!.clear();
    session.dispose();
  });

  test(
    'factory failure clears credentials and allows a fresh attempt',
    () async {
      final session = _Session();
      final supplied = <ModelSettings>[];
      final bloc = ConnectionBloc(
        coordinator: SessionConnection(
          connect: (settings) async {
            supplied.add(settings);
            if (supplied.length == 1) {
              throw StateError('private provider detail');
            }
            return session;
          },
        ),
      );
      final failed = status(bloc, ConnectionStatus.failure);
      bloc.submit(model: 'test-model', apiKey: 'first-key');
      final failure = await failed;
      expect(failure.error, ConnectionError.configuration);
      expect(failure.canSubmit, isTrue);
      expect(supplied.single.apiKey, isEmpty);
      final ready = status(bloc, ConnectionStatus.connected);
      bloc.submit(model: 'test-model', apiKey: 'second-key');
      await ready;
      // No view accepted this session, so the Bloc still owns its disposal.
      await bloc.close();
      expect(session.disposals, 1);
      expect(supplied.last.apiKey, isEmpty);
    },
  );

  test(
    'closing clears a pending key and disposes its late session once',
    () async {
      final pending = Completer<CommerceSession>();
      final session = _Session();
      ModelSettings? supplied;
      final bloc = ConnectionBloc(
        coordinator: SessionConnection(
          connect: (settings) {
            supplied = settings;
            return pending.future;
          },
        ),
      );
      final started = status(bloc, ConnectionStatus.connecting);
      bloc.submit(model: 'test-model', apiKey: 'pending-key');
      await started;
      final closing = bloc.close();
      expect(supplied!.apiKey, isEmpty);
      pending.complete(session);
      await closing;
      expect(session.disposals, 1);
      expect(bloc.takeConnectedSession(), isNull);
    },
  );

  test('same-frame duplicate submissions invoke the factory once', () async {
    final pending = Completer<CommerceSession>();
    final session = _Session();
    var calls = 0;
    final bloc = ConnectionBloc(
      coordinator: SessionConnection(
        connect: (_) {
          calls++;
          return pending.future;
        },
      ),
    );
    final started = status(bloc, ConnectionStatus.connecting);
    bloc.submit(model: 'test-model', apiKey: 'first-key');
    bloc.submit(model: 'test-model', apiKey: 'duplicate-key');
    await started;
    expect(calls, 1);
    final closing = bloc.close();
    pending.complete(session);
    await closing;
    expect(session.disposals, 1);
  });

  test(
    'invalid settings become a fixed error without calling the factory',
    () async {
      var calls = 0;
      final bloc = ConnectionBloc(
        coordinator: SessionConnection(
          connect: (_) async {
            calls++;
            return _Session();
          },
        ),
      );
      final failed = status(bloc, ConnectionStatus.failure);
      bloc.submit(model: 'model with spaces', apiKey: 'private-key');
      expect((await failed).error, ConnectionError.configuration);
      expect(calls, 0);
      await bloc.close();
    },
  );

  test('connection events and state diagnostics omit credentials', () async {
    final settings = ModelSettings(
      provider: 'googleai',
      model: 'test-model',
      apiKey: 'private-key-never-log',
    );
    final attempt = SessionConnection(connect: (_) async => _Session())
        .prepare(settings);
    expect(attempt.toString(), 'ConnectionAttempt(redacted)');
    expect(
      ConnectionSubmitted(attempt).toString(),
      'ConnectionSubmitted(redacted)',
    );
    expect(
      const ConnectionState().toString(),
      isNot(contains(settings.apiKey)),
    );
    attempt.cancel();
    expect(settings.apiKey, isEmpty);
  });
}
