import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'stylist_event.dart';
import 'stylist_state.dart';
import '../../../data/catalog/model/models.dart';
import '../../../data/stylist/model/model_settings.dart';

export 'stylist_event.dart';
export 'stylist_state.dart';

typedef StylistConnectionFactory = Future<CommerceSession> Function(
  ModelSettings settings,
);

/// UI session state and commands. No renderer, provider, or wire types escape.
/// The app owns and disposes a session after accepting it from the factory.
abstract class CommerceSession extends Bloc<StylistEvent, StylistState> {
  CommerceSession([super.initialState = const StylistState()]);

  bool get hasStarted => state.hasStarted;
  DemoJourney? get activeJourney => state.activeJourney;
  bool get isBusy => state.isBusy;
  String? get connectionError => state.connectionError;
  String? get inputError => state.inputError;
  String? get connectionNotice => state.connectionNotice;
  bool get canRetry => state.canRetry;
  bool get canStartBrief => state.canStartBrief;
  int get bagCount => state.bagCount;
  bool get hasLocalLibrary => state.hasLocalLibrary;
  Future<void> openBag() async {}
  Future<void> openSavedLooks() async {}
  Future<bool> restartChat() async => false;
  Future<void> retryLastTurn() async {}
  Future<void> startBrief(String message) async {}
  Future<void> startJourney(DemoJourney journey);
  Future<void> sendMessage(String message);

  /// Root ownership stays synchronous; close cancels owned asynchronous work.
  void dispose() => unawaited(close());
}
