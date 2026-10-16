import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/stylist/model/commerce_trace.dart';
import '../../../data/stylist/model/model_ui_catalog.dart';

sealed class CommerceInspectorEvent extends Equatable {
  const CommerceInspectorEvent();
}

final class CommerceInspectorVisibilityChanged extends CommerceInspectorEvent {
  const CommerceInspectorVisibilityChanged(this.inspecting);

  final bool inspecting;

  @override
  List<Object?> get props => [inspecting];
}

final class CommerceInspectorEntryRecorded extends CommerceInspectorEvent {
  const CommerceInspectorEntryRecorded(this.entry);

  final CommerceTraceEntry entry;

  @override
  List<Object?> get props => [entry];
}

final class CommerceInspectorState extends Equatable {
  CommerceInspectorState({
    this.inspecting = false,
    Iterable<CommerceTraceEntry> entries = const [],
  }) : entries = List.unmodifiable(entries);

  final bool inspecting;
  final List<CommerceTraceEntry> entries;

  @override
  List<Object?> get props => [inspecting, entries];
}

/// A separate feature queue keeps inspection responsive during a model turn.
/// Only the closed, redacted trace vocabulary can enter its in-memory history.
final class CommerceInspectorBloc
    extends Bloc<CommerceInspectorEvent, CommerceInspectorState> {
  CommerceInspectorBloc({required this.catalog})
    : super(CommerceInspectorState()) {
    on<CommerceInspectorVisibilityChanged>((event, emit) {
      emit(
        CommerceInspectorState(
          inspecting: event.inspecting,
          entries: state.entries,
        ),
      );
    });
    on<CommerceInspectorEntryRecorded>((event, emit) {
      final entries = [...state.entries, event.entry];
      emit(
        CommerceInspectorState(
          inspecting: state.inspecting,
          entries: entries.skip(
            (entries.length - historyLimit).clamp(0, historyLimit),
          ),
        ),
      );
    });
  }

  static const historyLimit = 100;
  final ModelUiCatalog catalog;

  void setInspecting(bool inspecting) {
    if (!isClosed) add(CommerceInspectorVisibilityChanged(inspecting));
  }

  void record(CommerceTraceEntry entry) {
    if (!isClosed) add(CommerceInspectorEntryRecorded(entry));
  }
}
