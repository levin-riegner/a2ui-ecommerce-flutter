import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'genkit_providers_test.dart' show providerReply;

Future<void> fill(WidgetTester tester) async {
  await tester.tap(find.text('Connect your model'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'test-model');
  await tester.enterText(fields.at(1), 'private-test-key');
}

void main() {
  testWidgets(
    'bundled BYOK has no service address, masks the key, and connects without network calls',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return providerReply('googleai');
      });
      await tester.pumpWidget(ReferenceApp(connectionClient: client));
      expect(
        tester.widget<ActionChip>(find.byType(ActionChip).first).onPressed,
        isNull,
      );
      await fill(tester);
      expect(find.text('Stylist service URL'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await tester.ensureVisible(find.text('Connect model'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Connect model'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('private-test-key'), findsNothing);
      expect(requests, isEmpty);
      expect(
        tester.widget<ActionChip>(find.byType(ActionChip).first).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Disconnect model'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ActionChip>(find.byType(ActionChip).first).onPressed,
        isNull,
      );
      expect(requests, isEmpty);
      await tester.tap(find.text('Connect your model'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      client.close();
    },
  );

  testWidgets(
    'compatible provider alone requires a base URL and rejects invalid addresses',
    (tester) async {
      await tester.pumpWidget(const ReferenceApp());
      await fill(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OpenAI-compatible').last);
      await tester.pumpAndSettle();
      expect(find.text('Provider API base URL'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'http://remote.example/v1');
      await tester.ensureVisible(find.text('Connect model'));
      await tester.tap(find.text('Connect model'));
      await tester.pumpAndSettle();
      expect(
        find.text('Use HTTPS or a local loopback HTTP address'),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
