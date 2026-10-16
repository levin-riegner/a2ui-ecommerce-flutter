import 'dart:async';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/commerce_session.dart';
import 'package:a2ui_flutter_commerce/presentation/connection/views/model_connection_form.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/model_settings.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/util/stylist_dependencies.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/remote/genkit_providers.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/catalog_snapshot.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'stylist_runtime_test.dart' show products;
import 'stylist_store_helpers.dart';

class SessionFake extends CommerceSession {
  int disposals = 0;
  @override
  bool get hasStarted => false;
  @override
  DemoJourney? get activeJourney => null;
  @override
  Future<void> sendMessage(String message) async {}
  @override
  Future<void> startJourney(DemoJourney journey) async {}
  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

Future<void> submit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'test-model');
  await tester.enterText(find.byType(TextFormField).at(1), 'test-key');
  await tester.ensureVisible(find.text('Connect model'));
  await tester.tap(find.text('Connect model'));
  await tester.pump();
}

void main() {
  testWidgets('connection form accepts a renderer-free session factory', (
    tester,
  ) async {
    final session = SessionFake();
    CommerceSession? accepted;
    ModelSettings? supplied;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelConnectionForm(
            connectionFactory: (settings) async {
              supplied = settings;
              return session;
            },
            onConnected: (value) => accepted = value,
          ),
        ),
      ),
    );
    await submit(tester);
    await tester.pumpAndSettle();
    expect(accepted, same(session));
    expect(supplied!.model, 'test-model');
    expect(session.disposals, 0);
    supplied!.clear();
    session.dispose();
  });

  testWidgets('dismissing setup disposes a late session exactly once', (
    tester,
  ) async {
    final pending = Completer<CommerceSession>();
    final session = SessionFake();
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelConnectionForm(
            connectionFactory: (_) => pending.future,
            onConnected: (_) => accepted = true,
          ),
        ),
      ),
    );
    await submit(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(session);
    await tester.pump();
    expect(accepted, isFalse);
    expect(session.disposals, 1);
  });

  testWidgets('replacing injected sessions transfers ownership exactly once', (
    tester,
  ) async {
    final first = SessionFake(), second = SessionFake();
    await tester.pumpWidget(ReferenceApp(agent: first));
    await tester.pumpWidget(ReferenceApp(agent: second));
    expect(first.disposals, 1);
    expect(second.disposals, 0);
    await tester.pumpWidget(const SizedBox());
    expect(second.disposals, 1);
  });

  test(
    'production composition uses injected catalog and store with zero requests',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        throw StateError('Setup must be offline');
      });
      final snapshot = CatalogSnapshot(
        products: products,
        revision: 'composition-test',
      );
      final settings = ModelSettings(
        provider: 'googleai',
        model: 'test',
        apiKey: 'test-key',
      );
      final agent = await StylistDependencies(
        catalog: MemoryCatalogSource(snapshot),
        provider: (settings) => GenkitProvider(settings, client: client),
        store: MemoryStylistStore(),
      ).connect(settings);
      expect(requests, 0);
      agent.dispose();
      expect(settings.apiKey, isEmpty);
      client.close();
    },
  );
  testWidgets(
    'late dialog connection cannot replace a newer injected session',
    (tester) async {
      final pending = Completer<CommerceSession>();
      final lateSession = SessionFake(), replacement = SessionFake();
      await tester.pumpWidget(
        ReferenceApp(connectionFactory: (_) => pending.future),
      );
      await tester.tap(find.text('Connect your model'));
      await tester.pumpAndSettle();
      await submit(tester);
      await tester.pumpWidget(ReferenceApp(agent: replacement));
      await tester.pump();
      pending.complete(lateSession);
      await tester.pumpAndSettle();
      expect(lateSession.disposals, 1);
      expect(replacement.disposals, 0);
      await tester.pumpWidget(const SizedBox());
      expect(replacement.disposals, 1);
    },
  );
}
