import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/l10n/l10n.dart';
import '../../data/stylist/model/commerce_trace.dart';
import '../../data/stylist/model/model_ui_catalog.dart';
import '../stylist/bloc/commerce_inspector_bloc.dart';

/// Opens diagnostics as a sheet without replacing the live surface.
class CommerceInspectionPane extends StatefulWidget {
  const CommerceInspectionPane({
    required this.bloc,
    required this.experience,
    this.inspectionPadding = EdgeInsets.zero,
    this.buttonRightOffset = 0,
    this.buttonTopOffset,
    this.plainButton = false,
    this.buttonForegroundColor = Colors.white,
    this.showButton = true,
    this.fullScreen = false,
    super.key,
  });

  final CommerceInspectorBloc bloc;
  final Widget experience;
  final EdgeInsets inspectionPadding;
  final double buttonRightOffset;
  final double? buttonTopOffset;
  final bool plainButton;
  final Color buttonForegroundColor;
  final bool showButton;
  final bool fullScreen;

  static Future<void> inspect(BuildContext context) =>
      context
          .findAncestorStateOfType<_CommerceInspectionPaneState>()
          ?._inspect() ??
      Future<void>.value();

  @override
  State<CommerceInspectionPane> createState() => _CommerceInspectionPaneState();
}

class _CommerceInspectionPaneState extends State<CommerceInspectionPane> {
  final _paneKey = GlobalKey();
  bool _open = false;

  Future<void> _inspect() async {
    if (_open) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _open = true);
    final bloc = widget.bloc;
    // Bottom-sheet routes remove top padding. Capture the window insets first.
    final safe = MediaQuery.viewPaddingOf(
      Navigator.of(context, rootNavigator: true).context,
    );
    bloc.setInspecting(true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black38,
        elevation: 0,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 240)),
        builder: (sheetContext) => LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Offset.zero & constraints.biggest;
            final pane =
                _paneKey.currentContext?.findRenderObject() as RenderBox?;
            final overlay =
                Navigator.of(sheetContext).overlay!.context.findRenderObject()
                    as RenderBox;
            final fullScreen =
                widget.fullScreen ||
                pane == null ||
                !pane.constraints.hasBoundedHeight;
            final bounds = fullScreen
                ? viewport
                : (pane.localToGlobal(Offset.zero, ancestor: overlay) &
                          pane.size)
                      .intersect(viewport);
            return Padding(
              padding: EdgeInsets.only(
                left: bounds.left,
                right: viewport.right - bounds.right,
                bottom: viewport.bottom - bounds.bottom,
              ),
              child: SizedBox(
                width: bounds.width,
                height: bounds.height,
                child: Material(
                  key: const ValueKey('commerce-inspector-sheet'),
                  color: Colors.black,
                  borderRadius: fullScreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: _InspectorTheme(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: (safe.top - bounds.top).clamp(0.0, safe.top),
                        bottom: (bounds.bottom - viewport.bottom + safe.bottom)
                            .clamp(0.0, safe.bottom),
                        right: widget.inspectionPadding.right,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 4, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.l10n.inspectorInspect,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey(
                                    'commerce-inspector-close',
                                  ),
                                  tooltip: context.l10n.inspectorClose,
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: CommerceInspector(bloc: bloc)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      if (!bloc.isClosed) bloc.setInspecting(false);
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      key: _paneKey,
      fit: constraints.hasBoundedHeight ? StackFit.expand : StackFit.loose,
      children: [
        ExcludeFocus(excluding: _open, child: widget.experience),
        if (widget.showButton)
          Positioned(
            top:
                widget.buttonTopOffset ??
                widget.inspectionPadding.top + (widget.fullScreen ? 4 : 16),
            right: widget.buttonRightOffset + 8,
            child: IconButton(
              key: const ValueKey('commerce-inspect-button'),
              tooltip: context.l10n.inspectorInspect,
              onPressed: _open ? null : _inspect,
              style: IconButton.styleFrom(
                foregroundColor: widget.buttonForegroundColor,
                backgroundColor: Colors.transparent,
                shape: const CircleBorder(),
                fixedSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              icon: widget.plainButton
                  ? const Icon(Icons.data_object, size: 24)
                  : Container(
                      key: const ValueKey('commerce-inspect-circle'),
                      width: widget.fullScreen ? 32 : 40,
                      height: widget.fullScreen ? 32 : 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Icon(
                        Icons.data_object,
                        size: widget.fullScreen ? 16 : 18,
                      ),
                    ),
            ),
          ),
      ],
    ),
  );
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xff27272a)
            : Colors.transparent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// Public learning view. It displays structural summaries, never HTTP captures,
/// prompt messages, provider credentials or model-authored prose.
class CommerceInspector extends StatefulWidget {
  const CommerceInspector({required this.bloc, super.key});

  final CommerceInspectorBloc bloc;

  @override
  State<CommerceInspector> createState() => _CommerceInspectorState();
}

class _CommerceInspectorState extends State<CommerceInspector> {
  bool _catalog = false;
  final _storage = PageStorageBucket();

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _storage,
    child: _InspectorTheme(
      child: BlocBuilder<CommerceInspectorBloc, CommerceInspectorState>(
        bloc: widget.bloc,
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _ViewButton(
                      label: context.l10n.inspectorExchanges,
                      icon: Icons.swap_vert,
                      selected: !_catalog,
                      onPressed: () => setState(() => _catalog = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ViewButton(
                      label: context.l10n.inspectorCatalog,
                      icon: Icons.widgets_outlined,
                      selected: _catalog,
                      onPressed: () => setState(() => _catalog = true),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _catalog
                  ? _CatalogList(catalog: widget.bloc.catalog)
                  : ListView(
                      key: const PageStorageKey('commerce-inspector-exchanges'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          context.l10n.inspectorTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(context.l10n.inspectorPrivacy),
                        const SizedBox(height: 8),
                        Text(context.l10n.inspectorAuthority),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.inspectorHistory(
                            state.entries.length,
                            CommerceInspectorBloc.historyLimit,
                          ),
                        ),
                        if (state.entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(context.l10n.inspectorEmpty),
                          ),
                        for (final entry in state.entries.reversed)
                          _ExchangeCard(key: ObjectKey(entry), entry: entry),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExchangeCard extends StatelessWidget {
  const _ExchangeCard({required this.entry, super.key});

  final CommerceTraceEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, explanation) = switch (entry.kind) {
      CommerceTraceKind.clientInput => (
        l10n.inspectorClientInput,
        l10n.inspectorClientExplanation,
      ),
      CommerceTraceKind.modelRequest => (
        l10n.inspectorModelRequest,
        l10n.inspectorRequestExplanation,
      ),
      CommerceTraceKind.modelResponse => (
        l10n.inspectorModelResponse,
        l10n.inspectorResponseExplanation,
      ),
      CommerceTraceKind.toolResult => (
        l10n.inspectorToolResult,
        l10n.inspectorToolResultExplanation,
      ),
      CommerceTraceKind.validation => (
        l10n.inspectorValidation,
        l10n.inspectorValidationExplanation,
      ),
      CommerceTraceKind.turnFailure => (
        l10n.inspectorTurnFailure,
        l10n.inspectorTurnFailureExplanation,
      ),
      CommerceTraceKind.surfaceCommit => (
        entry.details['recommendationChoice'] == 'modelSelected'
            ? l10n.inspectorModelSelected
            : l10n.inspectorHostComposed,
        l10n.inspectorSurfaceExplanation,
      ),
    };
    final source = switch (entry.details['source']) {
      'provider' => l10n.inspectorProvider,
      'offline' => l10n.inspectorOffline,
      'injected' => l10n.inspectorInjected,
      _ => null,
    };
    final component = entry.details['component'];
    final tools = entry.details['tools'];
    final tool = entry.details['tool'];
    final accepted = entry.details['accepted'];
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        key: PageStorageKey(entry),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (source != null)
              Text(source, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (component is String)
              Text(
                l10n.inspectorComponentChoice(component),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (tools is List && tools.isNotEmpty)
              Text(l10n.inspectorTools(tools.join(', '))),
            if (tool is String) Text(l10n.inspectorTools(tool)),
            if (accepted is bool)
              Text(accepted ? l10n.inspectorAccepted : l10n.inspectorRejected),
            Text(explanation),
          ],
        ),
        children: [_JsonStructure(value: entry.details)],
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.catalog});

  final ModelUiCatalog catalog;

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const PageStorageKey('commerce-inspector-catalog'),
    padding: const EdgeInsets.all(16),
    itemCount: catalog.entries.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inspectorCatalogCount(catalog.entries.length),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.inspectorCatalogExplanation),
            const SizedBox(height: 8),
            SelectionArea(child: Text(catalog.catalogId)),
          ],
        );
      }
      if (index == 1) {
        return Card(
          child: ExpansionTile(
            key: PageStorageKey('${catalog.catalogId}/host-actions'),
            title: Text(context.l10n.inspectorHostActions),
            subtitle: Text(context.l10n.inspectorHostActionsExplanation),
            childrenPadding: const EdgeInsets.all(12),
            children: [_JsonStructure(value: catalog.actionSchema)],
          ),
        );
      }
      final entry = catalog.entries[index - 2];
      final availability = switch (entry.availability) {
        ModelUiAvailability.modelSelectable => context.l10n.inspectorSelectable,
        ModelUiAvailability.hostControlled =>
          context.l10n.inspectorHostControlled,
        ModelUiAvailability.referenceOnly =>
          context.l10n.inspectorReferenceOnly,
      };
      return Card(
        child: ExpansionTile(
          key: PageStorageKey('${catalog.catalogId}/component/${entry.name}'),
          title: Text(entry.name),
          subtitle: Text(availability),
          childrenPadding: const EdgeInsets.all(12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.guidance),
            const SizedBox(height: 8),
            Text(
              context.l10n.inspectorSchema,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _JsonStructure(value: entry.schema),
          ],
        ),
      );
    },
  );
}

class _JsonStructure extends StatelessWidget {
  const _JsonStructure({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SelectionArea(
      child: Text(
        const JsonEncoder.withIndent('  ').convert(value),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
        ),
      ),
    ),
  );
}

class _InspectorTheme extends StatelessWidget {
  const _InspectorTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xffc3e5d0),
        surface: Colors.black,
        onSurface: Color(0xfff3f4f4),
        onSurfaceVariant: Color(0xffc4cccf),
      ),
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      cardTheme: const CardThemeData(color: Color(0xff18181b)),
    ),
    child: Material(color: Colors.black, child: child),
  );
}
