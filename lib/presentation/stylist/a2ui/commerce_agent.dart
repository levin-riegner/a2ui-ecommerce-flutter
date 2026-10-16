import 'package:genui/genui.dart';

import '../bloc/conversation_entry.dart';
import '../bloc/commerce_session.dart';
import '../bloc/commerce_inspector_bloc.dart';

/// The host contract for the stylist and test fixture agents.
abstract class CommerceAgent extends CommerceSession {
  CommerceAgent([super.initialState]);

  String? get latestInlineSurfaceId => state.latestInlineSurfaceId;
  List<CommerceConversationEntry> get conversationEntries {
    if (state.conversationEntries.isNotEmpty) return state.conversationEntries;
    final surfaceId = latestInlineSurfaceId;
    return [if (surfaceId != null) CommerceSurfaceEntry(surfaceId: surfaceId)];
  }

  String? get pendingInlineSurfaceId => state.pendingInlineSurfaceId;
  bool get hasDressingRoomSurface => state.hasDressingRoomSurface;
  SurfaceController get controller;
  Conversation get conversation;
  CommerceInspectorBloc? get inspector => null;

  @override
  Future<void> sendMessage(String message) =>
      conversation.sendRequest(ChatMessage.user(message));
}
