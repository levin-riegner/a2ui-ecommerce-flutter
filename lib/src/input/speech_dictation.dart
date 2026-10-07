import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// The native recognizer stays app-wide: its initialization callbacks cannot
/// be replaced when the occasion composer becomes the conversation composer.
abstract interface class DictationRecognizer {
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  });
  Future<void> listen(ValueChanged<String> onWords);
  Future<void> stop();
  Future<void> cancel();
}

class _NativeRecognizer implements DictationRecognizer {
  final _speech = SpeechToText();

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  }) => _speech.initialize(
    onStatus: onStatus,
    onError: (error) => onError(error.errorMsg),
  );

  @override
  Future<void> listen(ValueChanged<String> onWords) async {
    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        autoPunctuation: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() => _speech.cancel();
}

enum DictationPhase { idle, starting, listening, stopping }

/// Routes one native session to its owning composer. Native operations are
/// serialized so a late permission/listen completion cannot reopen a retired mic.
class SpeechDictation extends ChangeNotifier {
  SpeechDictation({required DictationRecognizer recognizer})
    // Public injection keeps the platform adapter private.
    // ignore: prefer_initializing_formals
    : _recognizer = recognizer;

  static final shared = SpeechDictation(recognizer: _NativeRecognizer());
  final DictationRecognizer _recognizer;
  Future<void>? _pending;
  Timer? _startupTimer;
  Timer? _completionTimer;
  Object? _completedOwner;
  ValueChanged<String>? _completedError;
  bool _ready = false;
  bool _acceptEvents = false;
  Object? _owner;
  int _session = 0;
  ValueChanged<String>? _onError;
  DictationPhase _phase = DictationPhase.idle;

  DictationPhase get phase => _phase;
  bool owns(Object owner) => identical(_owner, owner);

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending == null
        ? operation()
        : _pending!.then((_) => operation());
    // Each operation handles errors for its caller; keep the queue usable.
    _pending = result.catchError((Object _) {});
    return result;
  }

  Future<void> start(
    Object owner, {
    required ValueChanged<String> onWords,
    required ValueChanged<String> onError,
  }) {
    _clearCompletion();
    final session = ++_session;
    _acceptEvents = false;
    _startupTimer?.cancel();
    _owner = owner;
    _onError = onError;
    _phase = DictationPhase.starting;
    notifyListeners();
    return _enqueue(() async {
      try {
        if (_ready) await _recognizer.cancel();
        if (session != _session) return;
        if (!_ready) {
          _ready = await _recognizer.initialize(
            onStatus: _status,
            onError: _error,
          );
        }
        if (session != _session) return;
        if (!_ready) {
          _fail(
            'Enable microphone and speech recognition permissions to dictate. If dictation is unavailable on this device, you can still type.',
          );
          return;
        }
        _acceptEvents = true;
        _startupTimer = Timer(const Duration(seconds: 8), () {
          if (session == _session && _phase == DictationPhase.starting) {
            _fail(
              'The microphone did not start. Please try again or type your message.',
            );
          }
        });
        await _recognizer
            .listen((words) {
              if (session == _session) onWords(words);
            })
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        if (session == _session) {
          _fail(
            'Dictation could not start. Please try again or type your message.',
          );
        }
      }
    });
  }

  Future<void> stop(Object owner) {
    if (!owns(owner) || _phase != DictationPhase.listening) {
      return Future.value();
    }
    final session = _session;
    _phase = DictationPhase.stopping;
    notifyListeners();
    return _enqueue(() async {
      try {
        if (session == _session) await _recognizer.stop();
      } catch (_) {
        if (session == _session) {
          _fail('Dictation stopped. Your draft is still available.');
        }
      }
    });
  }

  Future<void> cancel(Object owner) {
    if (identical(_completedOwner, owner)) _clearCompletion();
    if (!owns(owner)) return Future.value();
    _finish();
    return _cancelNative();
  }

  Future<void> _cancelNative() => _enqueue(() async {
    if (!_ready) return;
    try {
      await _recognizer.cancel();
    } catch (_) {
      // The draft is already detached, including when the platform disappears.
    }
  });

  void _status(String status) {
    if (_owner == null || !_acceptEvents) return;
    if (status == SpeechToText.doneStatus) {
      final owner = _owner;
      final onError = _onError;
      _finish();
      // iOS sends doneNoResult before notifyError on recognition failure.
      // Cancelling here also makes speech_to_text suppress that error.
      // The native task has already ended; retain its error route briefly.
      _completedOwner = owner;
      _completedError = onError;
      _completionTimer = Timer(
        const Duration(milliseconds: 500),
        _clearCompletion,
      );
    } else if (status == SpeechToText.listeningStatus) {
      _startupTimer?.cancel();
      _phase = DictationPhase.listening;
      notifyListeners();
    } else if (status == SpeechToText.notListeningStatus) {
      _phase = DictationPhase.stopping;
      notifyListeners();
    }
  }

  void _error(String code) {
    final message = switch (code) {
      'error_no_match' || 'error_speech_timeout' =>
        'No speech detected. Tap the microphone to try again.',
      'error_permission' || 'error_audio' || 'error_not_allowed' =>
        'Check microphone and speech recognition permissions, then try again.',
      'error_unknown (300)' => 'Speech recognition could not initialize on this device. Please try again or type your message.',
      _ => 'Dictation is unavailable right now. Please try again or type your message.',
    };
    if (_owner == null || !_acceptEvents) {
      final onError = _completedError;
      _clearCompletion();
      onError?.call(message);
      return;
    }
    _fail(message);
  }

  void _clearCompletion() {
    _completionTimer?.cancel();
    _completionTimer = null;
    _completedOwner = null;
    _completedError = null;
  }

  void _fail(String message) {
    final onError = _onError;
    _finish();
    _cancelNative();
    onError?.call(message);
  }

  @override
  void dispose() {
    _clearCompletion();
    ++_session;
    _startupTimer?.cancel();
    _acceptEvents = false;
    _owner = null;
    _onError = null;
    unawaited(_cancelNative());
    super.dispose();
  }

  void _finish() {
    _clearCompletion();
    ++_session;
    _startupTimer?.cancel();
    _acceptEvents = false;
    _owner = null;
    _onError = null;
    _phase = DictationPhase.idle;
    notifyListeners();
  }
}
