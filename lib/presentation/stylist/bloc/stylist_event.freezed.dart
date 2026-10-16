// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stylist_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StylistEvent {
  int get requestId;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistEventCopyWith<StylistEvent> get copyWith =>
      _$StylistEventCopyWithImpl<StylistEvent>(
        this as StylistEvent,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistEvent &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId);
}

/// @nodoc
abstract mixin class $StylistEventCopyWith<$Res> {
  factory $StylistEventCopyWith(
    StylistEvent value,
    $Res Function(StylistEvent) _then,
  ) = _$StylistEventCopyWithImpl;
  @useResult
  $Res call({int requestId});
}

/// @nodoc
class _$StylistEventCopyWithImpl<$Res> implements $StylistEventCopyWith<$Res> {
  _$StylistEventCopyWithImpl(this._self, this._then);

  final StylistEvent _self;
  final $Res Function(StylistEvent) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? requestId = null}) {
    return _then(
      _self.copyWith(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [StylistEvent].
extension StylistEventPatterns on StylistEvent {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(StylistResumeRequested value)? resumeRequested,
    TResult Function(StylistJourneyStarted value)? journeyStarted,
    TResult Function(StylistBriefStarted value)? briefStarted,
    TResult Function(StylistMessageSubmitted value)? messageSubmitted,
    TResult Function(StylistBagOpened value)? bagOpened,
    TResult Function(StylistSavedLooksOpened value)? savedLooksOpened,
    TResult Function(StylistRetryRequested value)? retryRequested,
    TResult Function(StylistRestartRequested value)? restartRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case StylistResumeRequested() when resumeRequested != null:
        return resumeRequested(_that);
      case StylistJourneyStarted() when journeyStarted != null:
        return journeyStarted(_that);
      case StylistBriefStarted() when briefStarted != null:
        return briefStarted(_that);
      case StylistMessageSubmitted() when messageSubmitted != null:
        return messageSubmitted(_that);
      case StylistBagOpened() when bagOpened != null:
        return bagOpened(_that);
      case StylistSavedLooksOpened() when savedLooksOpened != null:
        return savedLooksOpened(_that);
      case StylistRetryRequested() when retryRequested != null:
        return retryRequested(_that);
      case StylistRestartRequested() when restartRequested != null:
        return restartRequested(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(StylistResumeRequested value) resumeRequested,
    required TResult Function(StylistJourneyStarted value) journeyStarted,
    required TResult Function(StylistBriefStarted value) briefStarted,
    required TResult Function(StylistMessageSubmitted value) messageSubmitted,
    required TResult Function(StylistBagOpened value) bagOpened,
    required TResult Function(StylistSavedLooksOpened value) savedLooksOpened,
    required TResult Function(StylistRetryRequested value) retryRequested,
    required TResult Function(StylistRestartRequested value) restartRequested,
  }) {
    final _that = this;
    switch (_that) {
      case StylistResumeRequested():
        return resumeRequested(_that);
      case StylistJourneyStarted():
        return journeyStarted(_that);
      case StylistBriefStarted():
        return briefStarted(_that);
      case StylistMessageSubmitted():
        return messageSubmitted(_that);
      case StylistBagOpened():
        return bagOpened(_that);
      case StylistSavedLooksOpened():
        return savedLooksOpened(_that);
      case StylistRetryRequested():
        return retryRequested(_that);
      case StylistRestartRequested():
        return restartRequested(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(StylistResumeRequested value)? resumeRequested,
    TResult? Function(StylistJourneyStarted value)? journeyStarted,
    TResult? Function(StylistBriefStarted value)? briefStarted,
    TResult? Function(StylistMessageSubmitted value)? messageSubmitted,
    TResult? Function(StylistBagOpened value)? bagOpened,
    TResult? Function(StylistSavedLooksOpened value)? savedLooksOpened,
    TResult? Function(StylistRetryRequested value)? retryRequested,
    TResult? Function(StylistRestartRequested value)? restartRequested,
  }) {
    final _that = this;
    switch (_that) {
      case StylistResumeRequested() when resumeRequested != null:
        return resumeRequested(_that);
      case StylistJourneyStarted() when journeyStarted != null:
        return journeyStarted(_that);
      case StylistBriefStarted() when briefStarted != null:
        return briefStarted(_that);
      case StylistMessageSubmitted() when messageSubmitted != null:
        return messageSubmitted(_that);
      case StylistBagOpened() when bagOpened != null:
        return bagOpened(_that);
      case StylistSavedLooksOpened() when savedLooksOpened != null:
        return savedLooksOpened(_that);
      case StylistRetryRequested() when retryRequested != null:
        return retryRequested(_that);
      case StylistRestartRequested() when restartRequested != null:
        return restartRequested(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int requestId)? resumeRequested,
    TResult Function(int requestId, DemoJourney journey)? journeyStarted,
    TResult Function(int requestId, String message)? briefStarted,
    TResult Function(
      int requestId,
      String message,
      Map<String, Object?>? action,
    )?
    messageSubmitted,
    TResult Function(int requestId)? bagOpened,
    TResult Function(int requestId)? savedLooksOpened,
    TResult Function(int requestId)? retryRequested,
    TResult Function(int requestId)? restartRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case StylistResumeRequested() when resumeRequested != null:
        return resumeRequested(_that.requestId);
      case StylistJourneyStarted() when journeyStarted != null:
        return journeyStarted(_that.requestId, _that.journey);
      case StylistBriefStarted() when briefStarted != null:
        return briefStarted(_that.requestId, _that.message);
      case StylistMessageSubmitted() when messageSubmitted != null:
        return messageSubmitted(_that.requestId, _that.message, _that.action);
      case StylistBagOpened() when bagOpened != null:
        return bagOpened(_that.requestId);
      case StylistSavedLooksOpened() when savedLooksOpened != null:
        return savedLooksOpened(_that.requestId);
      case StylistRetryRequested() when retryRequested != null:
        return retryRequested(_that.requestId);
      case StylistRestartRequested() when restartRequested != null:
        return restartRequested(_that.requestId);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int requestId) resumeRequested,
    required TResult Function(int requestId, DemoJourney journey)
    journeyStarted,
    required TResult Function(int requestId, String message) briefStarted,
    required TResult Function(
      int requestId,
      String message,
      Map<String, Object?>? action,
    )
    messageSubmitted,
    required TResult Function(int requestId) bagOpened,
    required TResult Function(int requestId) savedLooksOpened,
    required TResult Function(int requestId) retryRequested,
    required TResult Function(int requestId) restartRequested,
  }) {
    final _that = this;
    switch (_that) {
      case StylistResumeRequested():
        return resumeRequested(_that.requestId);
      case StylistJourneyStarted():
        return journeyStarted(_that.requestId, _that.journey);
      case StylistBriefStarted():
        return briefStarted(_that.requestId, _that.message);
      case StylistMessageSubmitted():
        return messageSubmitted(_that.requestId, _that.message, _that.action);
      case StylistBagOpened():
        return bagOpened(_that.requestId);
      case StylistSavedLooksOpened():
        return savedLooksOpened(_that.requestId);
      case StylistRetryRequested():
        return retryRequested(_that.requestId);
      case StylistRestartRequested():
        return restartRequested(_that.requestId);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int requestId)? resumeRequested,
    TResult? Function(int requestId, DemoJourney journey)? journeyStarted,
    TResult? Function(int requestId, String message)? briefStarted,
    TResult? Function(
      int requestId,
      String message,
      Map<String, Object?>? action,
    )?
    messageSubmitted,
    TResult? Function(int requestId)? bagOpened,
    TResult? Function(int requestId)? savedLooksOpened,
    TResult? Function(int requestId)? retryRequested,
    TResult? Function(int requestId)? restartRequested,
  }) {
    final _that = this;
    switch (_that) {
      case StylistResumeRequested() when resumeRequested != null:
        return resumeRequested(_that.requestId);
      case StylistJourneyStarted() when journeyStarted != null:
        return journeyStarted(_that.requestId, _that.journey);
      case StylistBriefStarted() when briefStarted != null:
        return briefStarted(_that.requestId, _that.message);
      case StylistMessageSubmitted() when messageSubmitted != null:
        return messageSubmitted(_that.requestId, _that.message, _that.action);
      case StylistBagOpened() when bagOpened != null:
        return bagOpened(_that.requestId);
      case StylistSavedLooksOpened() when savedLooksOpened != null:
        return savedLooksOpened(_that.requestId);
      case StylistRetryRequested() when retryRequested != null:
        return retryRequested(_that.requestId);
      case StylistRestartRequested() when restartRequested != null:
        return restartRequested(_that.requestId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class StylistResumeRequested extends StylistEvent {
  const StylistResumeRequested({this.requestId = 0}) : super._();

  @override
  @JsonKey()
  final int requestId;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistResumeRequestedCopyWith<StylistResumeRequested> get copyWith =>
      _$StylistResumeRequestedCopyWithImpl<StylistResumeRequested>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistResumeRequested &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId);
}

/// @nodoc
abstract mixin class $StylistResumeRequestedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistResumeRequestedCopyWith(
    StylistResumeRequested value,
    $Res Function(StylistResumeRequested) _then,
  ) = _$StylistResumeRequestedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId});
}

/// @nodoc
class _$StylistResumeRequestedCopyWithImpl<$Res>
    implements $StylistResumeRequestedCopyWith<$Res> {
  _$StylistResumeRequestedCopyWithImpl(this._self, this._then);

  final StylistResumeRequested _self;
  final $Res Function(StylistResumeRequested) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null}) {
    return _then(
      StylistResumeRequested(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class StylistJourneyStarted extends StylistEvent {
  const StylistJourneyStarted({this.requestId = 0, required this.journey})
    : super._();

  @override
  @JsonKey()
  final int requestId;
  final DemoJourney journey;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistJourneyStartedCopyWith<StylistJourneyStarted> get copyWith =>
      _$StylistJourneyStartedCopyWithImpl<StylistJourneyStarted>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistJourneyStarted &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.journey, journey) || other.journey == journey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId, journey);
}

/// @nodoc
abstract mixin class $StylistJourneyStartedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistJourneyStartedCopyWith(
    StylistJourneyStarted value,
    $Res Function(StylistJourneyStarted) _then,
  ) = _$StylistJourneyStartedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId, DemoJourney journey});
}

/// @nodoc
class _$StylistJourneyStartedCopyWithImpl<$Res>
    implements $StylistJourneyStartedCopyWith<$Res> {
  _$StylistJourneyStartedCopyWithImpl(this._self, this._then);

  final StylistJourneyStarted _self;
  final $Res Function(StylistJourneyStarted) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null, Object? journey = null}) {
    return _then(
      StylistJourneyStarted(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
        journey: null == journey
            ? _self.journey
            : journey // ignore: cast_nullable_to_non_nullable
                  as DemoJourney,
      ),
    );
  }
}

/// @nodoc

class StylistBriefStarted extends StylistEvent {
  const StylistBriefStarted({this.requestId = 0, required this.message})
    : super._();

  @override
  @JsonKey()
  final int requestId;
  final String message;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistBriefStartedCopyWith<StylistBriefStarted> get copyWith =>
      _$StylistBriefStartedCopyWithImpl<StylistBriefStarted>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistBriefStarted &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId, message);
}

/// @nodoc
abstract mixin class $StylistBriefStartedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistBriefStartedCopyWith(
    StylistBriefStarted value,
    $Res Function(StylistBriefStarted) _then,
  ) = _$StylistBriefStartedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId, String message});
}

/// @nodoc
class _$StylistBriefStartedCopyWithImpl<$Res>
    implements $StylistBriefStartedCopyWith<$Res> {
  _$StylistBriefStartedCopyWithImpl(this._self, this._then);

  final StylistBriefStarted _self;
  final $Res Function(StylistBriefStarted) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null, Object? message = null}) {
    return _then(
      StylistBriefStarted(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
        message: null == message
            ? _self.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class StylistMessageSubmitted extends StylistEvent {
  const StylistMessageSubmitted({
    this.requestId = 0,
    required this.message,
    Map<String, Object?>? action,
  }) : _action = action,
       super._();

  @override
  @JsonKey()
  final int requestId;
  final String message;
  final Map<String, Object?>? _action;
  Map<String, Object?>? get action {
    final value = _action;
    if (value == null) return null;
    if (_action is EqualUnmodifiableMapView) return _action;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistMessageSubmittedCopyWith<StylistMessageSubmitted> get copyWith =>
      _$StylistMessageSubmittedCopyWithImpl<StylistMessageSubmitted>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistMessageSubmitted &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._action, _action));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    requestId,
    message,
    const DeepCollectionEquality().hash(_action),
  );
}

/// @nodoc
abstract mixin class $StylistMessageSubmittedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistMessageSubmittedCopyWith(
    StylistMessageSubmitted value,
    $Res Function(StylistMessageSubmitted) _then,
  ) = _$StylistMessageSubmittedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId, String message, Map<String, Object?>? action});
}

/// @nodoc
class _$StylistMessageSubmittedCopyWithImpl<$Res>
    implements $StylistMessageSubmittedCopyWith<$Res> {
  _$StylistMessageSubmittedCopyWithImpl(this._self, this._then);

  final StylistMessageSubmitted _self;
  final $Res Function(StylistMessageSubmitted) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? requestId = null,
    Object? message = null,
    Object? action = freezed,
  }) {
    return _then(
      StylistMessageSubmitted(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
        message: null == message
            ? _self.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        action: freezed == action
            ? _self._action
            : action // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>?,
      ),
    );
  }
}

/// @nodoc

class StylistBagOpened extends StylistEvent {
  const StylistBagOpened({this.requestId = 0}) : super._();

  @override
  @JsonKey()
  final int requestId;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistBagOpenedCopyWith<StylistBagOpened> get copyWith =>
      _$StylistBagOpenedCopyWithImpl<StylistBagOpened>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistBagOpened &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId);
}

/// @nodoc
abstract mixin class $StylistBagOpenedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistBagOpenedCopyWith(
    StylistBagOpened value,
    $Res Function(StylistBagOpened) _then,
  ) = _$StylistBagOpenedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId});
}

/// @nodoc
class _$StylistBagOpenedCopyWithImpl<$Res>
    implements $StylistBagOpenedCopyWith<$Res> {
  _$StylistBagOpenedCopyWithImpl(this._self, this._then);

  final StylistBagOpened _self;
  final $Res Function(StylistBagOpened) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null}) {
    return _then(
      StylistBagOpened(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class StylistSavedLooksOpened extends StylistEvent {
  const StylistSavedLooksOpened({this.requestId = 0}) : super._();

  @override
  @JsonKey()
  final int requestId;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistSavedLooksOpenedCopyWith<StylistSavedLooksOpened> get copyWith =>
      _$StylistSavedLooksOpenedCopyWithImpl<StylistSavedLooksOpened>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistSavedLooksOpened &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId);
}

/// @nodoc
abstract mixin class $StylistSavedLooksOpenedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistSavedLooksOpenedCopyWith(
    StylistSavedLooksOpened value,
    $Res Function(StylistSavedLooksOpened) _then,
  ) = _$StylistSavedLooksOpenedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId});
}

/// @nodoc
class _$StylistSavedLooksOpenedCopyWithImpl<$Res>
    implements $StylistSavedLooksOpenedCopyWith<$Res> {
  _$StylistSavedLooksOpenedCopyWithImpl(this._self, this._then);

  final StylistSavedLooksOpened _self;
  final $Res Function(StylistSavedLooksOpened) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null}) {
    return _then(
      StylistSavedLooksOpened(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class StylistRetryRequested extends StylistEvent {
  const StylistRetryRequested({this.requestId = 0}) : super._();

  @override
  @JsonKey()
  final int requestId;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistRetryRequestedCopyWith<StylistRetryRequested> get copyWith =>
      _$StylistRetryRequestedCopyWithImpl<StylistRetryRequested>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistRetryRequested &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId);
}

/// @nodoc
abstract mixin class $StylistRetryRequestedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistRetryRequestedCopyWith(
    StylistRetryRequested value,
    $Res Function(StylistRetryRequested) _then,
  ) = _$StylistRetryRequestedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId});
}

/// @nodoc
class _$StylistRetryRequestedCopyWithImpl<$Res>
    implements $StylistRetryRequestedCopyWith<$Res> {
  _$StylistRetryRequestedCopyWithImpl(this._self, this._then);

  final StylistRetryRequested _self;
  final $Res Function(StylistRetryRequested) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null}) {
    return _then(
      StylistRetryRequested(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class StylistRestartRequested extends StylistEvent {
  const StylistRestartRequested({this.requestId = 0}) : super._();

  @override
  @JsonKey()
  final int requestId;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistRestartRequestedCopyWith<StylistRestartRequested> get copyWith =>
      _$StylistRestartRequestedCopyWithImpl<StylistRestartRequested>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistRestartRequested &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId);
}

/// @nodoc
abstract mixin class $StylistRestartRequestedCopyWith<$Res>
    implements $StylistEventCopyWith<$Res> {
  factory $StylistRestartRequestedCopyWith(
    StylistRestartRequested value,
    $Res Function(StylistRestartRequested) _then,
  ) = _$StylistRestartRequestedCopyWithImpl;
  @override
  @useResult
  $Res call({int requestId});
}

/// @nodoc
class _$StylistRestartRequestedCopyWithImpl<$Res>
    implements $StylistRestartRequestedCopyWith<$Res> {
  _$StylistRestartRequestedCopyWithImpl(this._self, this._then);

  final StylistRestartRequested _self;
  final $Res Function(StylistRestartRequested) _then;

  /// Create a copy of StylistEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? requestId = null}) {
    return _then(
      StylistRestartRequested(
        requestId: null == requestId
            ? _self.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}
