import 'package:genui/genui.dart';

import 'conversation_entry.dart';
import 'commerce_session.dart';

/// The host contract for the stylist and test fixture agents.
abstract class CommerceAgent extends CommerceSession {
  String? get latestInlineSurfaceId;
  List<CommerceConversationEntry> get conversationEntries {
    final surfaceId = latestInlineSurfaceId;
    return [if (surfaceId != null) CommerceSurfaceEntry(surfaceId: surfaceId)];
  }

  String? get pendingInlineSurfaceId => null;
  bool get hasDressingRoomSurface => hasStarted;
  SurfaceController get controller;
  Conversation get conversation;

  @override
  Future<void> sendMessage(String message) =>
      conversation.sendRequest(ChatMessage.user(message));
}
