import 'package:freezed_annotation/freezed_annotation.dart';

import 'conversation_entry.dart';
import '../../../data/catalog/model/models.dart';

part 'stylist_state.freezed.dart';

/// A renderer-independent snapshot of the current screen and conversation.
/// Controller handles and mutable model/provider requests never enter state.
@Freezed(toStringOverride: false)
abstract class StylistState with _$StylistState {
  const StylistState._();

  const factory StylistState({
    @Default(false) bool hasStarted,
    DemoJourney? activeJourney,
    @Default(0) int queuedTurns,
    String? connectionError,
    String? inputError,
    String? connectionNotice,
    @Default(false) bool hasFailedTurn,
    @Default(false) bool canStartBrief,
    @Default(0) int bagCount,
    @Default(false) bool hasLocalLibrary,
    String? latestInlineSurfaceId,
    String? pendingInlineSurfaceId,
    @Default(false) bool hasDressingRoomSurface,
    @Default(0) int surfaceRevision,
    @Default([]) List<CommerceConversationEntry> conversationEntries,
  }) = _StylistState;

  bool get isBusy => queuedTurns > 0;
  bool get canRetry => hasFailedTurn && !isBusy;

  @override
  String toString() =>
      'StylistState(started: $hasStarted, busy: $isBusy, '
      'entries: ${conversationEntries.length})';
}
