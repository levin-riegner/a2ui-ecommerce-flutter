import 'dart:async';

import '../service/remote/genkit_providers.dart';
import '../model/stylist_result.dart';
import '../service/runtime/stylist_runtime.dart';
import '../../catalog/model/models.dart';

/// Owns one connected stylist's runtime, provider and cancellation lifetime.
/// The runtime coordinates catalog facts and persisted drafts; the repository
/// exposes their results without leaking provider or renderer SDK handles.
class StylistRepository {
  StylistRepository({required StylistRuntime runtime, GenkitProvider? provider})
    // Constructor injection deliberately keeps owned SDK resources private.
    // ignore: prefer_initializing_formals
    : _runtime = runtime,
      // ignore: prefer_initializing_formals
      _provider = provider;

  final StylistRuntime _runtime;
  final GenkitProvider? _provider;
  bool _closed = false;
  Future<void>? _closing;

  int get bagCount => _closed ? 0 : _runtime.bagCount;
  bool get hasLocalLibrary => !_closed && _runtime.hasLocalLibrary;
  String? get localStorageNotice => _runtime.localStorageNotice;
  String? get failureMessage => _provider?.failureMessage;

  String? restartBrief(String message) => restartStylistBrief(message);

  Future<bool> loadLocalState() {
    _ensureOpen();
    return _runtime.loadLocalState();
  }

  void reset({DemoJourney? journey}) {
    _ensureOpen();
    _runtime.reset(journey: journey);
  }

  /// Presentation validates the candidate through this callback *before* the
  /// runtime commits state or storage. A later BLoC listener cannot replace it.
  Future<StylistTurnResult> turn(
    Map<String, dynamic> input, {
    void Function(String text)? onText,
    void Function(StylistTurnResult result)? onOutfitPreview,
    FutureOr<void> Function(StylistTurnResult result)? validateResult,
  }) {
    _ensureOpen();
    return _runtime.turn(
      input,
      onText: onText,
      onOutfitPreview: onOutfitPreview,
      validateResult: validateResult,
    );
  }

  void cancelActiveTurn() {
    if (!_closed) _runtime.cancelActiveTurn();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Model connection closed');
  }

  /// Revoke credentials and active work immediately, then await SDK shutdown.
  /// Multiple owners attempting cleanup share the same completion.
  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    try {
      _runtime.cancelActiveTurn();
    } finally {
      try {
        _provider?.dispose();
      } finally {
        await _runtime.dispose();
      }
    }
  }
}
