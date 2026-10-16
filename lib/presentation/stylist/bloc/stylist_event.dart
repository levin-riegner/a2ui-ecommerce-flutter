import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../data/catalog/model/models.dart';

part 'stylist_event.freezed.dart';

/// A command carries only its input and identity. Awaiting callers are tracked
/// outside the event, so immutable events contain no completion controllers.
/// The log representation deliberately excludes user text and action payloads.
@Freezed(toStringOverride: false)
sealed class StylistEvent with _$StylistEvent {
  const StylistEvent._();

  const factory StylistEvent.resumeRequested({@Default(0) int requestId}) =
      StylistResumeRequested;

  const factory StylistEvent.journeyStarted({
    @Default(0) int requestId,
    required DemoJourney journey,
  }) = StylistJourneyStarted;

  const factory StylistEvent.briefStarted({
    @Default(0) int requestId,
    required String message,
  }) = StylistBriefStarted;

  const factory StylistEvent.messageSubmitted({
    @Default(0) int requestId,
    required String message,
    Map<String, Object?>? action,
  }) = StylistMessageSubmitted;

  const factory StylistEvent.bagOpened({@Default(0) int requestId}) =
      StylistBagOpened;

  const factory StylistEvent.savedLooksOpened({@Default(0) int requestId}) =
      StylistSavedLooksOpened;

  const factory StylistEvent.retryRequested({@Default(0) int requestId}) =
      StylistRetryRequested;

  const factory StylistEvent.restartRequested({@Default(0) int requestId}) =
      StylistRestartRequested;

  @override
  String toString() => '$runtimeType(request: $requestId)';
}
