import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/conversation_entry.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import 'stylist_library_test.dart' show completed, libraryCatalog;
import 'stylist_store_helpers.dart';

Future<GenkitAgent> resume(MemoryStylistStore store) async {
  final seed = await completed(store: store);
  await seed.dispose();
  final agent = GenkitAgent(
    StylistRuntime(products: libraryCatalog, store: store),
  );
  await agent.resumeLocalState();
  return agent;
}

Future<void> closeBag(GenkitAgent agent) => agent.conversation.sendRequest(
  ChatMessage.user(
    '',
    parts: [
      UiInteractionPart.create('{"action":{"name":"close_bag","context":{}}}'),
    ],
  ),
);

void main() {
  for (final withHistory in [false, true]) {
    test(
      'basket replacement releases orphan surfaces; history=$withHistory',
      () async {
        final agent = await resume(MemoryStylistStore());
        addTearDown(agent.close);
        if (withHistory) {
          await agent.sendMessage('What materials are these pieces?');
        }
        final entryCount = agent.conversationEntries.length;
        expect(entryCount, withHistory ? 3 : 1);
        final historicalIds = agent.conversationEntries
            .whereType<CommerceSurfaceEntry>()
            .map((entry) => entry.surfaceId)
            .where((id) => id != agent.latestInlineSurfaceId)
            .toSet();
        for (var cycle = 0; cycle < 6; cycle++) {
          final previous = agent.latestInlineSurfaceId!;
          await agent.openBag();
          expect(agent.connectionError, isNull);
          expect(agent.renderer.contains(previous), isFalse);
          await closeBag(agent);
          expect(agent.connectionError, isNull);
          expect(agent.conversationEntries.length, entryCount);
          expect(
            agent.renderer.surfaceIds,
            unorderedEquals([
              'dressing-room',
              ...historicalIds,
              agent.latestInlineSurfaceId,
            ]),
          );
        }
      },
    );
  }

  test(
    'failed basket replacement retains the last committed surface',
    () async {
      final store = MemoryStylistStore();
      final agent = await resume(store);
      addTearDown(agent.close);
      final previous = agent.latestInlineSurfaceId;
      final surfaceIds = agent.renderer.surfaceIds;
      final entries = agent.conversationEntries;
      store.beforeWrite = () async =>
          throw StateError('Simulated storage failure');
      await agent.openBag();
      expect(agent.inputError, isNotNull);
      expect(agent.latestInlineSurfaceId, previous);
      expect(agent.renderer.surfaceIds, surfaceIds);
      expect(agent.conversationEntries, entries);
      store.beforeWrite = null;
      await agent.openBag();
      expect(agent.inputError, isNull);
      expect(agent.renderer.contains(previous!), isFalse);
      expect(agent.renderer.surfaceIds.length, surfaceIds.length);
    },
  );
}
