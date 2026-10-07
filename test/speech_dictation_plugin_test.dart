import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/input/speech_dictation.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  testWidgets(
    'native speech_to_text callbacks fill the draft before manual send',
    (tester) async {
      const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' || 'listen' => true,
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      Future<void> native(String method, Object payload) async {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, payload)),
          null,
        );
        await tester.pump();
      }

      Future<void> words(String text, {bool finalResult = false}) => native(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': text, 'confidence': .95},
          ],
          'resultType': finalResult ? 2 : 0,
        }),
      );

      final controller = TextEditingController();
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StylistComposer(
              controller: controller,
              onSubmitted: sent.add,
            ),
          ),
        ),
      );
      expect(
        calls,
        isEmpty,
      ); // No permissions or microphone access before a tap.
      await tester.tap(find.byTooltip('Dictate message'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['initialize', 'listen']);
      final options = calls.last.arguments as Map;
      expect(options['listenMode'], ListenMode.dictation.index);
      expect(options['partialResults'], isTrue);
      expect(options['autoPunctuation'], isTrue);
      await native('notifyStatus', 'listening');
      expect(find.byTooltip('Stop dictation'), findsOneWidget);
      await words('A wedding');
      expect(controller.text, 'A wedding');
      await words('A wedding in Berlin');
      expect(controller.text, 'A wedding in Berlin');
      expect(sent, isEmpty);

      await tester.tap(find.byTooltip('Stop dictation'));
      await tester.pump();
      expect(calls.where((call) => call.method == 'stop'), hasLength(1));
      await words('A wedding in Berlin, under €800.', finalResult: true);
      await native('notifyStatus', 'done');
      expect(controller.text, 'A wedding in Berlin, under €800.');
      expect(find.byTooltip('Dictate message'), findsOneWidget);
      expect(sent, isEmpty);
      await tester.tap(find.byTooltip('Send'));
      expect(sent, ['A wedding in Berlin, under €800.']);
      expect(SpeechDictation.shared.phase, DictationPhase.idle);

      // The iOS plugin reports doneNoResult before the terminal error. Do not
      // cancel between these callbacks or speech_to_text hides the failure.
      controller.text = 'Keep my draft';
      await tester.tap(find.byTooltip('Dictate message'));
      await tester.pumpAndSettle();
      await native('notifyStatus', 'listening');
      final cancels = calls.where((call) => call.method == 'cancel').length;
      await native('notifyStatus', 'doneNoResult');
      expect(SpeechDictation.shared.phase, DictationPhase.idle);
      expect(
        calls.where((call) => call.method == 'cancel'),
        hasLength(cancels),
      );
      await native(
        'notifyError',
        jsonEncode({'errorMsg': 'error_unknown (300)', 'permanent': true}),
      );
      expect(find.textContaining('could not initialize'), findsOneWidget);
      expect(controller.text, 'Keep my draft');
      expect(sent, ['A wedding in Berlin, under €800.']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();
    },
  );
}
