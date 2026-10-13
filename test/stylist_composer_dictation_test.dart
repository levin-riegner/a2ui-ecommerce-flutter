import 'dart:async';

import 'package:a2ui_flutter_commerce/src/input/speech_dictation.dart';
import 'package:a2ui_flutter_commerce/src/layout/adaptive_pane_layout.dart';
import 'package:a2ui_flutter_commerce/src/layout/stylist_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recognizer implements DictationRecognizer {
  bool available = true;
  Completer<bool>? permission;
  ValueChanged<String>? status;
  ValueChanged<String>? error;
  final results = <ValueChanged<String>>[];
  int initializations = 0, stops = 0, cancellations = 0;
  bool notifyOnCancel = false;
  bool notifyOnListen = true;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  }) async {
    ++initializations;
    status = onStatus;
    error = onError;
    return permission == null ? available : await permission!.future;
  }

  @override
  Future<void> listen(ValueChanged<String> onWords) async {
    results.add(onWords);
    if (notifyOnListen) status!('listening');
  }

  @override
  Future<void> stop() async => ++stops;
  @override
  Future<void> cancel() async {
    ++cancellations;
    if (notifyOnCancel) status?.call('done');
  }
}

void main() {
  late _Recognizer recognizer;
  late SpeechDictation dictation;
  late TextEditingController controller;
  late List<String> sent;

  setUp(() {
    recognizer = _Recognizer();
    dictation = SpeechDictation(recognizer: recognizer);
    controller = TextEditingController();
    sent = [];
  });

  Future<void> mount(WidgetTester tester, {bool enabled = true}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StylistComposer(
              controller: controller,
              dictation: dictation,
              enabled: enabled,
              onSubmitted: sent.add,
            ),
          ),
        ),
      );

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Dictate message'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
    dictation.dispose();
  }

  testWidgets(
    'partial and final words replace the selection without auto-send',
    (tester) async {
      controller.value = const TextEditingValue(
        text: 'For Berlin tomorrow',
        selection: TextSelection(baseOffset: 4, extentOffset: 10),
      );
      await mount(tester);
      await start(tester);
      expect(find.byTooltip('Stop dictation'), findsOneWidget);
      recognizer.results.last('Paris');
      await tester.pump();
      expect(controller.text, 'For Paris tomorrow');
      recognizer.results.last('Paris in October');
      await tester.pump();
      expect(controller.text, 'For Paris in October tomorrow');
      expect(controller.selection.baseOffset, 20);
      expect(sent, isEmpty);
      await tester.tap(find.byTooltip('Stop dictation'));
      await tester.pump();
      expect(recognizer.stops, 1);
      recognizer.results.last('Paris in November');
      recognizer.status!('done');
      await tester.pump();
      expect(controller.text, 'For Paris in November tomorrow');
      expect(find.byTooltip('Dictate message'), findsOneWidget);
      await tester.tap(find.byTooltip('Send'));
      expect(sent, ['For Paris in November tomorrow']);
      await unmount(tester);
    },
  );

  testWidgets('manual edit and send reject late transcription', (tester) async {
    await mount(tester);
    await start(tester);
    final firstResult = recognizer.results.last;
    firstResult('A wedding');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'A dinner');
    firstResult('A wedding in Berlin');
    await tester.pump();
    expect(controller.text, 'A dinner');
    expect(dictation.phase, DictationPhase.idle);
    await start(tester);
    final secondResult = recognizer.results.last;
    secondResult('tomorrow');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    secondResult('tomorrow in Paris');
    await tester.pump();
    expect(sent, ['A dinner tomorrow']);
    expect(controller.text, 'A dinner tomorrow');
    expect(dictation.phase, DictationPhase.idle);
    await unmount(tester);
  });

  testWidgets('denied permissions keep text usable and can be retried', (
    tester,
  ) async {
    recognizer.available = false;
    controller.text = 'My draft';
    await mount(tester);
    await start(tester);
    expect(recognizer.results, isEmpty);
    expect(controller.text, 'My draft');
    expect(find.textContaining('Enable microphone'), findsOneWidget);
    expect(find.byTooltip('Dictate message'), findsOneWidget);
    recognizer.available = true;
    await start(tester);
    expect(recognizer.results, hasLength(1));
    await unmount(tester);
  });

  testWidgets('silent native startup failure returns to typing', (
    tester,
  ) async {
    recognizer.notifyOnListen = false;
    controller.text = 'My draft';
    await mount(tester);
    await start(tester);
    expect(dictation.phase, DictationPhase.starting);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(dictation.phase, DictationPhase.idle);
    expect(controller.text, 'My draft');
    expect(find.textContaining('microphone did not start'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('disposal during permission request never starts listening', (
    tester,
  ) async {
    recognizer.permission = Completer<bool>();
    await mount(tester);
    await start(tester);
    await tester.pumpWidget(const SizedBox());
    recognizer.permission!.complete(true);
    await tester.pump();
    expect(recognizer.results, isEmpty);
    expect(dictation.phase, DictationPhase.idle);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'busy and background transitions retire the mic and retain draft',
    (tester) async {
      await mount(tester);
      await start(tester);
      recognizer.results.last('My occasion');
      await tester.pump();
      await mount(tester, enabled: false);
      recognizer.results.last('A late result');
      await tester.pump();
      expect(controller.text, 'My occasion');
      expect(dictation.phase, DictationPhase.idle);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('stylist-microphone')),
            )
            .onPressed,
        isNull,
      );
      await mount(tester);
      await start(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      recognizer.results.last('Another late result');
      await tester.pump();
      expect(controller.text, 'My occasion');
      expect(dictation.phase, DictationPhase.idle);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await unmount(tester);
    },
  );

  testWidgets(
    'native errors show recovery and callbacks survive composer replacement',
    (tester) async {
      await mount(tester);
      await start(tester);
      recognizer.error!('error_no_match');
      await tester.pump();
      expect(find.textContaining('No speech detected'), findsOneWidget);
      expect(dictation.phase, DictationPhase.idle);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      recognizer.notifyOnCancel = true;
      await mount(tester);
      await start(tester);
      expect(recognizer.initializations, 1);
      expect(dictation.phase, DictationPhase.listening);
      recognizer.results.last('A summer wedding');
      await tester.pump();
      expect(controller.text, 'A summer wedding');
      recognizer.status!('done');
      await tester.pump();
      expect(dictation.phase, DictationPhase.idle);
      await unmount(tester);
    },
  );

  testWidgets(
    'button edges are tappable and keyboard send submits trimmed text',
    (tester) async {
      await mount(tester);
      final mic = find.byKey(const ValueKey('stylist-microphone'));
      final send = find.byKey(const ValueKey('stylist-submit-Send'));
      expect(tester.getSize(mic), const Size(44, 48));
      expect(tester.getSize(send), const Size(44, 48));
      expect(
        tester.getRect(mic).right,
        lessThanOrEqualTo(tester.getRect(send).left),
      );
      await tester.tapAt(tester.getTopRight(mic) + const Offset(-2, 24));
      await tester.pump();
      expect(dictation.phase, DictationPhase.listening);
      await tester.enterText(find.byType(TextField), '  A dinner  ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      expect(sent, ['A dinner']);
      await unmount(tester);
    },
  );

  testWidgets(
    'glass footer reserves multiline height and final content stays reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: Scaffold(
              body: AdaptivePaneLayout(
                overlayFooter: true,
                header: const SizedBox(height: 48),
                primary: const SizedBox(
                  height: 1000,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text('Last content'),
                  ),
                ),
                secondary: const SizedBox(),
                footer: StylistComposerDock(
                  child: StylistComposer(
                    controller: controller,
                    dictation: dictation,
                    onSubmitted: sent.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      final mic = tester.getRect(
        find.byKey(const ValueKey('stylist-microphone')),
      );
      // The visible circle keeps 8px pill padding; its larger touch target
      // extends another 6px within the pill.
      expect(tester.getRect(find.byType(StylistComposer)).bottom, 844 - 34 - 8);
      expect(mic.bottom, lessThanOrEqualTo(844 - 34 - 6));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('stylist-microphone-circle')))
            .bottom,
        lessThanOrEqualTo(844 - 34 - 12),
      );
      controller.text = 'A wedding in Berlin\nAn outdoor ceremony\nCocktail dress code\nAround €800\nComfortable shoes';
      await tester.pumpAndSettle();
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('compact-pane-scroll')),
      );
      final dock = tester.getSize(find.byType(StylistComposerDock));
      expect((scroll.padding! as EdgeInsets).bottom, dock.height + 16);
      await tester.drag(
        find.byKey(const ValueKey('compact-pane-scroll')),
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Last content')).bottom,
        lessThan(tester.getRect(find.byType(StylistComposerDock)).top),
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );
}
