// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stylist_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StylistState {
  bool get hasStarted;
  DemoJourney? get activeJourney;
  int get queuedTurns;
  String? get connectionError;
  String? get inputError;
  String? get connectionNotice;
  bool get hasFailedTurn;
  bool get canStartBrief;
  int get bagCount;
  bool get hasLocalLibrary;
  String? get latestInlineSurfaceId;
  String? get pendingInlineSurfaceId;
  bool get hasDressingRoomSurface;
  int get surfaceRevision;
  List<CommerceConversationEntry> get conversationEntries;

  /// Create a copy of StylistState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StylistStateCopyWith<StylistState> get copyWith =>
      _$StylistStateCopyWithImpl<StylistState>(
        this as StylistState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StylistState &&
            (identical(other.hasStarted, hasStarted) ||
                other.hasStarted == hasStarted) &&
            (identical(other.activeJourney, activeJourney) ||
                other.activeJourney == activeJourney) &&
            (identical(other.queuedTurns, queuedTurns) ||
                other.queuedTurns == queuedTurns) &&
            (identical(other.connectionError, connectionError) ||
                other.connectionError == connectionError) &&
            (identical(other.inputError, inputError) ||
                other.inputError == inputError) &&
            (identical(other.connectionNotice, connectionNotice) ||
                other.connectionNotice == connectionNotice) &&
            (identical(other.hasFailedTurn, hasFailedTurn) ||
                other.hasFailedTurn == hasFailedTurn) &&
            (identical(other.canStartBrief, canStartBrief) ||
                other.canStartBrief == canStartBrief) &&
            (identical(other.bagCount, bagCount) ||
                other.bagCount == bagCount) &&
            (identical(other.hasLocalLibrary, hasLocalLibrary) ||
                other.hasLocalLibrary == hasLocalLibrary) &&
            (identical(other.latestInlineSurfaceId, latestInlineSurfaceId) ||
                other.latestInlineSurfaceId == latestInlineSurfaceId) &&
            (identical(other.pendingInlineSurfaceId, pendingInlineSurfaceId) ||
                other.pendingInlineSurfaceId == pendingInlineSurfaceId) &&
            (identical(other.hasDressingRoomSurface, hasDressingRoomSurface) ||
                other.hasDressingRoomSurface == hasDressingRoomSurface) &&
            (identical(other.surfaceRevision, surfaceRevision) ||
                other.surfaceRevision == surfaceRevision) &&
            const DeepCollectionEquality().equals(
              other.conversationEntries,
              conversationEntries,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    hasStarted,
    activeJourney,
    queuedTurns,
    connectionError,
    inputError,
    connectionNotice,
    hasFailedTurn,
    canStartBrief,
    bagCount,
    hasLocalLibrary,
    latestInlineSurfaceId,
    pendingInlineSurfaceId,
    hasDressingRoomSurface,
    surfaceRevision,
    const DeepCollectionEquality().hash(conversationEntries),
  );
}

/// @nodoc
abstract mixin class $StylistStateCopyWith<$Res> {
  factory $StylistStateCopyWith(
    StylistState value,
    $Res Function(StylistState) _then,
  ) = _$StylistStateCopyWithImpl;
  @useResult
  $Res call({
    bool hasStarted,
    DemoJourney? activeJourney,
    int queuedTurns,
    String? connectionError,
    String? inputError,
    String? connectionNotice,
    bool hasFailedTurn,
    bool canStartBrief,
    int bagCount,
    bool hasLocalLibrary,
    String? latestInlineSurfaceId,
    String? pendingInlineSurfaceId,
    bool hasDressingRoomSurface,
    int surfaceRevision,
    List<CommerceConversationEntry> conversationEntries,
  });
}

/// @nodoc
class _$StylistStateCopyWithImpl<$Res> implements $StylistStateCopyWith<$Res> {
  _$StylistStateCopyWithImpl(this._self, this._then);

  final StylistState _self;
  final $Res Function(StylistState) _then;

  /// Create a copy of StylistState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasStarted = null,
    Object? activeJourney = freezed,
    Object? queuedTurns = null,
    Object? connectionError = freezed,
    Object? inputError = freezed,
    Object? connectionNotice = freezed,
    Object? hasFailedTurn = null,
    Object? canStartBrief = null,
    Object? bagCount = null,
    Object? hasLocalLibrary = null,
    Object? latestInlineSurfaceId = freezed,
    Object? pendingInlineSurfaceId = freezed,
    Object? hasDressingRoomSurface = null,
    Object? surfaceRevision = null,
    Object? conversationEntries = null,
  }) {
    return _then(
      StylistState(
        hasStarted: null == hasStarted
            ? _self.hasStarted
            : hasStarted // ignore: cast_nullable_to_non_nullable
                  as bool,
        activeJourney: freezed == activeJourney
            ? _self.activeJourney
            : activeJourney // ignore: cast_nullable_to_non_nullable
                  as DemoJourney?,
        queuedTurns: null == queuedTurns
            ? _self.queuedTurns
            : queuedTurns // ignore: cast_nullable_to_non_nullable
                  as int,
        connectionError: freezed == connectionError
            ? _self.connectionError
            : connectionError // ignore: cast_nullable_to_non_nullable
                  as String?,
        inputError: freezed == inputError
            ? _self.inputError
            : inputError // ignore: cast_nullable_to_non_nullable
                  as String?,
        connectionNotice: freezed == connectionNotice
            ? _self.connectionNotice
            : connectionNotice // ignore: cast_nullable_to_non_nullable
                  as String?,
        hasFailedTurn: null == hasFailedTurn
            ? _self.hasFailedTurn
            : hasFailedTurn // ignore: cast_nullable_to_non_nullable
                  as bool,
        canStartBrief: null == canStartBrief
            ? _self.canStartBrief
            : canStartBrief // ignore: cast_nullable_to_non_nullable
                  as bool,
        bagCount: null == bagCount
            ? _self.bagCount
            : bagCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hasLocalLibrary: null == hasLocalLibrary
            ? _self.hasLocalLibrary
            : hasLocalLibrary // ignore: cast_nullable_to_non_nullable
                  as bool,
        latestInlineSurfaceId: freezed == latestInlineSurfaceId
            ? _self.latestInlineSurfaceId
            : latestInlineSurfaceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        pendingInlineSurfaceId: freezed == pendingInlineSurfaceId
            ? _self.pendingInlineSurfaceId
            : pendingInlineSurfaceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        hasDressingRoomSurface: null == hasDressingRoomSurface
            ? _self.hasDressingRoomSurface
            : hasDressingRoomSurface // ignore: cast_nullable_to_non_nullable
                  as bool,
        surfaceRevision: null == surfaceRevision
            ? _self.surfaceRevision
            : surfaceRevision // ignore: cast_nullable_to_non_nullable
                  as int,
        conversationEntries: null == conversationEntries
            ? _self.conversationEntries
            : conversationEntries // ignore: cast_nullable_to_non_nullable
                  as List<CommerceConversationEntry>,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [StylistState].
extension StylistStatePatterns on StylistState {
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_StylistState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StylistState() when $default != null:
        return $default(_that);
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
  TResult map<TResult extends Object?>(
    TResult Function(_StylistState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StylistState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_StylistState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StylistState() when $default != null:
        return $default(_that);
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
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
      bool hasStarted,
      DemoJourney? activeJourney,
      int queuedTurns,
      String? connectionError,
      String? inputError,
      String? connectionNotice,
      bool hasFailedTurn,
      bool canStartBrief,
      int bagCount,
      bool hasLocalLibrary,
      String? latestInlineSurfaceId,
      String? pendingInlineSurfaceId,
      bool hasDressingRoomSurface,
      int surfaceRevision,
      List<CommerceConversationEntry> conversationEntries,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StylistState() when $default != null:
        return $default(
          _that.hasStarted,
          _that.activeJourney,
          _that.queuedTurns,
          _that.connectionError,
          _that.inputError,
          _that.connectionNotice,
          _that.hasFailedTurn,
          _that.canStartBrief,
          _that.bagCount,
          _that.hasLocalLibrary,
          _that.latestInlineSurfaceId,
          _that.pendingInlineSurfaceId,
          _that.hasDressingRoomSurface,
          _that.surfaceRevision,
          _that.conversationEntries,
        );
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
  TResult when<TResult extends Object?>(
    TResult Function(
      bool hasStarted,
      DemoJourney? activeJourney,
      int queuedTurns,
      String? connectionError,
      String? inputError,
      String? connectionNotice,
      bool hasFailedTurn,
      bool canStartBrief,
      int bagCount,
      bool hasLocalLibrary,
      String? latestInlineSurfaceId,
      String? pendingInlineSurfaceId,
      bool hasDressingRoomSurface,
      int surfaceRevision,
      List<CommerceConversationEntry> conversationEntries,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StylistState():
        return $default(
          _that.hasStarted,
          _that.activeJourney,
          _that.queuedTurns,
          _that.connectionError,
          _that.inputError,
          _that.connectionNotice,
          _that.hasFailedTurn,
          _that.canStartBrief,
          _that.bagCount,
          _that.hasLocalLibrary,
          _that.latestInlineSurfaceId,
          _that.pendingInlineSurfaceId,
          _that.hasDressingRoomSurface,
          _that.surfaceRevision,
          _that.conversationEntries,
        );
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
      bool hasStarted,
      DemoJourney? activeJourney,
      int queuedTurns,
      String? connectionError,
      String? inputError,
      String? connectionNotice,
      bool hasFailedTurn,
      bool canStartBrief,
      int bagCount,
      bool hasLocalLibrary,
      String? latestInlineSurfaceId,
      String? pendingInlineSurfaceId,
      bool hasDressingRoomSurface,
      int surfaceRevision,
      List<CommerceConversationEntry> conversationEntries,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StylistState() when $default != null:
        return $default(
          _that.hasStarted,
          _that.activeJourney,
          _that.queuedTurns,
          _that.connectionError,
          _that.inputError,
          _that.connectionNotice,
          _that.hasFailedTurn,
          _that.canStartBrief,
          _that.bagCount,
          _that.hasLocalLibrary,
          _that.latestInlineSurfaceId,
          _that.pendingInlineSurfaceId,
          _that.hasDressingRoomSurface,
          _that.surfaceRevision,
          _that.conversationEntries,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _StylistState extends StylistState {
  const _StylistState({
    this.hasStarted = false,
    this.activeJourney,
    this.queuedTurns = 0,
    this.connectionError,
    this.inputError,
    this.connectionNotice,
    this.hasFailedTurn = false,
    this.canStartBrief = false,
    this.bagCount = 0,
    this.hasLocalLibrary = false,
    this.latestInlineSurfaceId,
    this.pendingInlineSurfaceId,
    this.hasDressingRoomSurface = false,
    this.surfaceRevision = 0,
    List<CommerceConversationEntry> conversationEntries = const [],
  }) : _conversationEntries = conversationEntries,
       super._();

  @override
  @JsonKey()
  final bool hasStarted;
  @override
  final DemoJourney? activeJourney;
  @override
  @JsonKey()
  final int queuedTurns;
  @override
  final String? connectionError;
  @override
  final String? inputError;
  @override
  final String? connectionNotice;
  @override
  @JsonKey()
  final bool hasFailedTurn;
  @override
  @JsonKey()
  final bool canStartBrief;
  @override
  @JsonKey()
  final int bagCount;
  @override
  @JsonKey()
  final bool hasLocalLibrary;
  @override
  final String? latestInlineSurfaceId;
  @override
  final String? pendingInlineSurfaceId;
  @override
  @JsonKey()
  final bool hasDressingRoomSurface;
  @override
  @JsonKey()
  final int surfaceRevision;
  final List<CommerceConversationEntry> _conversationEntries;
  @override
  @JsonKey()
  List<CommerceConversationEntry> get conversationEntries {
    if (_conversationEntries is EqualUnmodifiableListView)
      return _conversationEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_conversationEntries);
  }

  /// Create a copy of StylistState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StylistStateCopyWith<_StylistState> get copyWith =>
      __$StylistStateCopyWithImpl<_StylistState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StylistState &&
            (identical(other.hasStarted, hasStarted) ||
                other.hasStarted == hasStarted) &&
            (identical(other.activeJourney, activeJourney) ||
                other.activeJourney == activeJourney) &&
            (identical(other.queuedTurns, queuedTurns) ||
                other.queuedTurns == queuedTurns) &&
            (identical(other.connectionError, connectionError) ||
                other.connectionError == connectionError) &&
            (identical(other.inputError, inputError) ||
                other.inputError == inputError) &&
            (identical(other.connectionNotice, connectionNotice) ||
                other.connectionNotice == connectionNotice) &&
            (identical(other.hasFailedTurn, hasFailedTurn) ||
                other.hasFailedTurn == hasFailedTurn) &&
            (identical(other.canStartBrief, canStartBrief) ||
                other.canStartBrief == canStartBrief) &&
            (identical(other.bagCount, bagCount) ||
                other.bagCount == bagCount) &&
            (identical(other.hasLocalLibrary, hasLocalLibrary) ||
                other.hasLocalLibrary == hasLocalLibrary) &&
            (identical(other.latestInlineSurfaceId, latestInlineSurfaceId) ||
                other.latestInlineSurfaceId == latestInlineSurfaceId) &&
            (identical(other.pendingInlineSurfaceId, pendingInlineSurfaceId) ||
                other.pendingInlineSurfaceId == pendingInlineSurfaceId) &&
            (identical(other.hasDressingRoomSurface, hasDressingRoomSurface) ||
                other.hasDressingRoomSurface == hasDressingRoomSurface) &&
            (identical(other.surfaceRevision, surfaceRevision) ||
                other.surfaceRevision == surfaceRevision) &&
            const DeepCollectionEquality().equals(
              other._conversationEntries,
              _conversationEntries,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    hasStarted,
    activeJourney,
    queuedTurns,
    connectionError,
    inputError,
    connectionNotice,
    hasFailedTurn,
    canStartBrief,
    bagCount,
    hasLocalLibrary,
    latestInlineSurfaceId,
    pendingInlineSurfaceId,
    hasDressingRoomSurface,
    surfaceRevision,
    const DeepCollectionEquality().hash(_conversationEntries),
  );
}

/// @nodoc
abstract mixin class _$StylistStateCopyWith<$Res>
    implements $StylistStateCopyWith<$Res> {
  factory _$StylistStateCopyWith(
    _StylistState value,
    $Res Function(_StylistState) _then,
  ) = __$StylistStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    bool hasStarted,
    DemoJourney? activeJourney,
    int queuedTurns,
    String? connectionError,
    String? inputError,
    String? connectionNotice,
    bool hasFailedTurn,
    bool canStartBrief,
    int bagCount,
    bool hasLocalLibrary,
    String? latestInlineSurfaceId,
    String? pendingInlineSurfaceId,
    bool hasDressingRoomSurface,
    int surfaceRevision,
    List<CommerceConversationEntry> conversationEntries,
  });
}

/// @nodoc
class __$StylistStateCopyWithImpl<$Res>
    implements _$StylistStateCopyWith<$Res> {
  __$StylistStateCopyWithImpl(this._self, this._then);

  final _StylistState _self;
  final $Res Function(_StylistState) _then;

  /// Create a copy of StylistState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? hasStarted = null,
    Object? activeJourney = freezed,
    Object? queuedTurns = null,
    Object? connectionError = freezed,
    Object? inputError = freezed,
    Object? connectionNotice = freezed,
    Object? hasFailedTurn = null,
    Object? canStartBrief = null,
    Object? bagCount = null,
    Object? hasLocalLibrary = null,
    Object? latestInlineSurfaceId = freezed,
    Object? pendingInlineSurfaceId = freezed,
    Object? hasDressingRoomSurface = null,
    Object? surfaceRevision = null,
    Object? conversationEntries = null,
  }) {
    return _then(
      _StylistState(
        hasStarted: null == hasStarted
            ? _self.hasStarted
            : hasStarted // ignore: cast_nullable_to_non_nullable
                  as bool,
        activeJourney: freezed == activeJourney
            ? _self.activeJourney
            : activeJourney // ignore: cast_nullable_to_non_nullable
                  as DemoJourney?,
        queuedTurns: null == queuedTurns
            ? _self.queuedTurns
            : queuedTurns // ignore: cast_nullable_to_non_nullable
                  as int,
        connectionError: freezed == connectionError
            ? _self.connectionError
            : connectionError // ignore: cast_nullable_to_non_nullable
                  as String?,
        inputError: freezed == inputError
            ? _self.inputError
            : inputError // ignore: cast_nullable_to_non_nullable
                  as String?,
        connectionNotice: freezed == connectionNotice
            ? _self.connectionNotice
            : connectionNotice // ignore: cast_nullable_to_non_nullable
                  as String?,
        hasFailedTurn: null == hasFailedTurn
            ? _self.hasFailedTurn
            : hasFailedTurn // ignore: cast_nullable_to_non_nullable
                  as bool,
        canStartBrief: null == canStartBrief
            ? _self.canStartBrief
            : canStartBrief // ignore: cast_nullable_to_non_nullable
                  as bool,
        bagCount: null == bagCount
            ? _self.bagCount
            : bagCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hasLocalLibrary: null == hasLocalLibrary
            ? _self.hasLocalLibrary
            : hasLocalLibrary // ignore: cast_nullable_to_non_nullable
                  as bool,
        latestInlineSurfaceId: freezed == latestInlineSurfaceId
            ? _self.latestInlineSurfaceId
            : latestInlineSurfaceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        pendingInlineSurfaceId: freezed == pendingInlineSurfaceId
            ? _self.pendingInlineSurfaceId
            : pendingInlineSurfaceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        hasDressingRoomSurface: null == hasDressingRoomSurface
            ? _self.hasDressingRoomSurface
            : hasDressingRoomSurface // ignore: cast_nullable_to_non_nullable
                  as bool,
        surfaceRevision: null == surfaceRevision
            ? _self.surfaceRevision
            : surfaceRevision // ignore: cast_nullable_to_non_nullable
                  as int,
        conversationEntries: null == conversationEntries
            ? _self._conversationEntries
            : conversationEntries // ignore: cast_nullable_to_non_nullable
                  as List<CommerceConversationEntry>,
      ),
    );
  }
}
