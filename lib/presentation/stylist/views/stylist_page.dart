import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:foldable/foldable.dart';
import 'package:genui/genui.dart';

import '../../../app/l10n/l10n.dart';
import '../../../app/navigation/router/app_router.dart';
import '../../../data/catalog/model/models.dart';
import '../../connection/views/model_connection_form.dart';
import '../../gallery/commerce_inspector.dart';
import '../../shared/design_system/views/brand_lockup.dart';
import '../../shared/design_system/views/commerce/commerce_components.dart';
import '../../shared/design_system/views/commerce/finalized_left_components.dart';
import '../../shared/design_system/views/commerce/finalized_shared_components.dart';
import '../../shared/design_system/views/commerce/occasion_artwork.dart';
import '../../shared/layout/adaptive_pane_layout.dart';
import '../../shared/layout/duo_layout_adapter.dart';
import '../../shared/layout/stylist_bag_overlay.dart';
import '../../shared/layout/stylist_composer.dart';
import '../../shared/layout/stylist_layout.dart';
import '../../shared/layout/stylist_surface_motion.dart';
import '../a2ui/commerce_agent.dart';
import '../bloc/commerce_session.dart';
import '../bloc/conversation_entry.dart';

class StylistPage extends StatefulWidget {
  const StylistPage({
    super.key,
    required this.agent,
    required this.onConnected,
    this.onDisconnect,
    required this.connectionFactory,
    this.sessionBuilder,
  });

  final CommerceSession? agent;
  final ValueChanged<CommerceSession> onConnected;
  final VoidCallback? onDisconnect;
  final StylistConnectionFactory connectionFactory;
  final Widget Function(CommerceSession session, VoidCallback onNewJourney)?
  sessionBuilder;

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage>
    with SingleTickerProviderStateMixin {
  bool _changingView = false;
  bool _confirmingRestart = false;
  late final _viewFade = AnimationController(
    vsync: this,
    duration: StylistSurfaceMotion.duration,
    value: 1,
  );
  late final _viewCurve = CurvedAnimation(
    parent: _viewFade,
    curve: Curves.easeInOutCubic,
  );

  @override
  void dispose() {
    _viewCurve.dispose();
    _viewFade.dispose();
    super.dispose();
  }

  Future<void> _changeView(Future<void> Function() change) async {
    if (_changingView) return;
    setState(() => _changingView = true);
    _viewFade.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : StylistSurfaceMotion.duration;
    try {
      await _viewFade.reverse();
      if (!mounted) return;
      await change();
      if (!mounted) return;
      await _viewFade.forward();
    } finally {
      if (mounted) {
        _viewFade.value = 1;
        setState(() => _changingView = false);
      }
    }
  }

  Future<void> _openStyling(Future<void> Function() start) async {
    Future<void>? turn;
    await _changeView(() async {
      turn = start();
    });
    if (turn != null) await turn;
  }

  Future<void> _restartChat() async {
    if (_confirmingRestart || _changingView) return;
    _confirmingRestart = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        animationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('restart-look-dialog'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: const BoxConstraints(maxWidth: 400),
          scrollable: true,
          title: Text(context.l10n.restartTitle),
          content: Text(context.l10n.restartDescription),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.l10n.restartConfirm),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  autofocus: true,
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: const Color(0xff18181b),
                    side: const BorderSide(color: Color(0xff18181b)),
                    textStyle: Theme.of(dialogContext).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    shape: Theme.of(dialogContext)
                        .filledButtonTheme
                        .style
                        ?.shape
                        ?.resolve({}),
                  ),
                  child: Text(context.l10n.keepStyling),
                ),
              ],
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _changeView(() async {
        final restarted = await widget.agent?.restartChat() ?? true;
        if (!restarted) return;
      });
    } finally {
      _confirmingRestart = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FadeTransition(
        key: const ValueKey('stylist-view-fade'),
        opacity: _viewCurve,
        child: IgnorePointer(
          ignoring: _changingView,
          child: _SessionBuilder(
            session: agent,
            builder: (context) {
              if (agent == null || !agent.hasStarted) {
                return _StartScreen(
                  onConnect: agent == null
                      ? () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => Dialog(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: ModelConnectionForm(
                                  connectionFactory: widget.connectionFactory,
                                  onConnected: (value) {
                                    Navigator.of(dialogContext).pop();
                                    if (!mounted) {
                                      value.dispose();
                                      return;
                                    }
                                    widget.onConnected(value);
                                  },
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                  onDisconnect: widget.onDisconnect,
                  onSelect: agent == null
                      ? null
                      : (journey) =>
                            _openStyling(() => agent.startJourney(journey)),
                  onStartBrief: agent?.canStartBrief == true
                      ? (message) =>
                            _openStyling(() => agent!.startBrief(message))
                      : null,
                  isBusy: agent?.isBusy ?? false,
                  onOpenGallery: () =>
                      const ComponentCatalogRoute().push<void>(context),
                );
              }
              void newJourney() => _restartChat();
              final builder = widget.sessionBuilder;
              if (builder != null) return builder(agent, newJourney);
              if (agent is! CommerceAgent) {
                throw StateError('A custom session requires a sessionBuilder.');
              }
              return StylistBagOverlay(
                agent: agent,
                child: _ResponsiveShell(
                  agent: agent,
                  onNewJourney: _restartChat,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StartScreen extends StatelessWidget {
  const _StartScreen({
    required this.onSelect,
    required this.onOpenGallery,
    this.isBusy = false,
    this.onConnect,
    this.onDisconnect,
    this.onStartBrief,
  });

  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final Future<void> Function(DemoJourney journey)? onSelect;
  final Future<void> Function(String message)? onStartBrief;
  final VoidCallback onOpenGallery;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final fold = DuoLayoutScope.of(context);
        final closed = fold.status == HingeStatus.closed;
        final horizontalInsets = closed
            ? const EdgeInsets.only(left: 16, right: 8)
            : const EdgeInsets.symmetric(horizontal: StylistLayout.gutter);
        final innerDisplay = fold.capabilities.isFoldable && !closed;
        final innerPortrait =
            fold.capabilities.isFoldable &&
            !closed &&
            constraints.maxHeight > constraints.maxWidth;
        final threadMinHeight = innerPortrait
            ? 0.0
            : math.max(
                0.0,
                constraints.maxHeight -
                    (closed ? 72 : 80) -
                    StylistLayout.composerBottomClearance -
                    68,
              );
        return AdaptivePaneLayout(
          compactSecondaryFirst: false,
          showSecondaryInCompact: !closed,
          primaryBottomInset: StylistLayout.composerBottomClearance,
          extendPrimaryIntoBottomPadding: innerDisplay,
          overlayHeader: true,
          overlayFooter: onStartBrief != null,
          stackSecondaryInPortrait: fold.capabilities.isFoldable && !closed,
          portraitHeaderHeight: 80,
          secondaryScrollable: false,
          extendSecondaryToEdges: true,
          secondaryBackgroundColor: Colors.black,
          secondaryPadding: EdgeInsets.zero,
          panePadding: horizontalInsets.copyWith(
            top: closed ? 8 : (innerPortrait ? 16 : 0),
            bottom: 8,
          ),
          header: ClipRect(
            key: const ValueKey('alder-header'),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ColoredBox(
                color: Colors.white.withValues(alpha: .8),
                child: Padding(
                  padding: closed
                      ? const EdgeInsets.fromLTRB(16, 24, 8, 16)
                      : const EdgeInsets.fromLTRB(32, 32, 32, 24),
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      children: [const Expanded(child: BrandLockup())],
                    ),
                  ),
                ),
              ),
            ),
          ),
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: threadMinHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _StartIntroduction(),
                    const SizedBox(height: 24),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0x0d000000),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label: context.l10n.occasionExamples,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 151,
                          height: 7,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 151,
                            maxWidth: 151,
                            minHeight: 8,
                            maxHeight: 8,
                            child: SvgPicture.asset(
                              'assets/images/occasions/start-eyebrow.svg',
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final example in _occasionExamples) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: StylistLayout.startContentMaxWidth,
                          ),
                          child: _OccasionSuggestion(
                            message: example.message,
                            onPressed: isBusy || onSelect == null
                                ? null
                                : () {
                                    if (onStartBrief != null) {
                                      onStartBrief!(example.message);
                                    } else {
                                      onSelect!(example.journey);
                                    }
                                  },
                          ),
                        ),
                      ),
                      if (example != _occasionExamples.last)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              // Keep host catalog/settings actions accessible below the opening
              // composition, outside the space reserved for the docked input.
              const SizedBox(height: 76),
              OutlinedButton.icon(
                onPressed: onOpenGallery,
                icon: const Icon(Icons.grid_view_outlined),
                label: Text(context.l10n.exploreCatalog),
              ),
              if (onDisconnect != null)
                TextButton(
                  onPressed: isBusy ? null : onDisconnect,
                  child: Text(context.l10n.disconnectModel),
                ),
            ],
          ),
          secondary: const _MosaicPreview(),
          footer: onStartBrief != null
              ? StylistComposerDock(
                  padding: horizontalInsets.copyWith(top: 24),
                  child: _CustomBriefEntry(
                    onStart: onStartBrief!,
                    isBusy: isBusy,
                  ),
                )
              : Padding(
                  padding: closed
                      ? const EdgeInsets.fromLTRB(16, 16, 8, 0)
                      : horizontalInsets.copyWith(top: 16, bottom: 24),
                  child: onConnect != null
                      ? FilledButton(
                          onPressed: onConnect,
                          child: Text(context.l10n.connectModelTitle),
                        )
                      : const SizedBox.shrink(),
                ),
        );
      },
    ),
  );
}

class _StartIntroduction extends StatelessWidget {
  const _StartIntroduction();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.occasionTitle,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w400,
          color: const Color(0xff18181b),
          height: 1.2,
          letterSpacing: -.75,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.occasionDescription,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          height: 22 / 15,
          letterSpacing: 0,
          color: Colors.black.withValues(alpha: .75),
        ),
      ),
    ],
  );
}

const _occasionExamples = [
  (
    journey: DemoJourney.lisbon,
    message: 'A summer lunch in Lisbon in June — a midi dress and sandals, under €500 for the whole outfit',
  ),
  (
    journey: DemoJourney.paris,
    message: 'A weekend in Paris in October — a sweater, trousers, sneakers and a jacket, casual style, under €650 for the whole outfit',
  ),
  (
    journey: DemoJourney.berlin,
    message: 'First day at a creative agency in Berlin in September — a shirt, tailored trousers and loafers, smart casual, under €700 for the whole outfit',
  ),
];

class _OccasionSuggestion extends StatelessWidget {
  const _OccasionSuggestion({required this.message, this.onPressed});
  final String message;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xfff2f2f2),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/occasions/suggestion-sparkle.svg',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -.25,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CustomBriefEntry extends StatefulWidget {
  const _CustomBriefEntry({required this.onStart, required this.isBusy});

  final Future<void> Function(String message) onStart;
  final bool isBusy;

  @override
  State<_CustomBriefEntry> createState() => _CustomBriefEntryState();
}

class _CustomBriefEntryState extends State<_CustomBriefEntry> {
  final _controller = TextEditingController();

  void _submit() {
    final message = _controller.text.trim();
    if (message.isEmpty || widget.isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onStart(message);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StylistComposer(
    controller: _controller,
    enabled: !widget.isBusy,
    fieldKey: const ValueKey('custom-brief-occasion'),
    fieldLabel: context.l10n.occasionField,
    submitLabel: context.l10n.startLook,
    onSubmitted: (_) => _submit(),
  );
}

class _MosaicPreview extends StatelessWidget {
  const _MosaicPreview();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : width * 1.4;
      final columnWidth = AdaptivePaneScope.isSplitOf(context)
          ? (width - DuoLayoutScope.mediaForLayout(context).padding.right - 4) /
                2
          : (width - 8) / 2.4;
      return SizedBox(
        key: const ValueKey('occasion-mosaic'),
        height: height,
        child: ColoredBox(
          color: Colors.white,
          child: ClipRect(
            child: Stack(
              children: [
                for (final column in [
                  (index: 0, images: [1, 2, 3]),
                  (index: 1, images: [4, 5, 6, 7]),
                  (index: 2, images: [8, 9, 10]),
                ])
                  Positioned(
                    left: column.index * (columnWidth + 4),
                    top: 0,
                    bottom: 0,
                    width: columnWidth,
                    child: OverflowBox(
                      maxHeight: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final number in column.images) ...[
                            OccasionArtwork(
                              seed: number,
                              width: columnWidth,
                              height: columnWidth * 4 / 3,
                            ),
                            if (number != column.images.last)
                              const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ResponsiveShell extends StatelessWidget {
  const _ResponsiveShell({required this.agent, required this.onNewJourney});

  final CommerceAgent agent;
  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final fold = DuoLayoutScope.of(context);
        final cover = fold.status == HingeStatus.closed;
        final innerDisplay = fold.capabilities.isFoldable && !cover;
        final gutter = cover || (!innerDisplay && constraints.maxWidth < 600)
            ? StylistLayout.compactGutter
            : StylistLayout.gutter;
        final layout = AdaptivePaneLayout(
          overlayFooter: true,
          overlayHeader: true,
          primaryBottomInset: StylistLayout.composerBottomClearance,
          extendPrimaryIntoBottomPadding: innerDisplay,
          panePadding: EdgeInsets.fromLTRB(gutter, 32, gutter, 8),
          secondaryPadding: EdgeInsets.zero,
          compactSecondaryPadding: const EdgeInsets.symmetric(horizontal: 16),
          secondaryScrollable: false,
          extendSecondaryToEdges: true,
          showSecondaryInCompact: !cover || agent.hasStarted,
          compactPaneGap: 32,
          followPrimaryEnd: true,
          primaryFollowTrigger: agent.latestInlineSurfaceId == null
              ? null
              : agent.pendingInlineSurfaceId ??
                    (agent.conversationEntries
                                .whereType<CommerceSurfaceEntry>()
                                .length >
                            1
                        ? agent.latestInlineSurfaceId
                        : null),
          holdInitialPrimaryBeginning:
              agent.conversationEntries
                      .whereType<CommerceUserMessage>()
                      .length <=
                  1 &&
              agent.conversationEntries
                      .whereType<CommerceSurfaceEntry>()
                      .length <=
                  1,
          stackSecondaryInPortrait:
              !cover && (agent.hasStarted || fold.capabilities.isFoldable),
          primary: _ChatSurface(agent: agent),
          secondaryBackgroundColor: Colors.black,
          secondaryBackgroundOnlyInBookMode: true,
          secondary: _DressingPanel(
            agent: agent,
            onNewJourney: onNewJourney,
            inspectionInToolbar: !innerDisplay,
          ),
          header: _MobileHeader(
            onNewJourney: onNewJourney,
            showInspect: !innerDisplay && agent.inspector != null,
            showBag: !innerDisplay && constraints.maxWidth < 600,
            bagCount: agent.bagCount,
            onBag: agent.hasLocalLibrary && !agent.isBusy
                ? agent.openBag
                : null,
          ),
          footer: StylistComposerDock(
            padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 0),
            child: _ChatComposer(agent: agent),
          ),
        );
        final inspector = agent.inspector;
        return inspector == null
            ? layout
            : CommerceInspectionPane(
                bloc: inspector,
                experience: layout,
                fullScreen: true,
                showButton: false,
                inspectionPadding: EdgeInsets.only(
                  right: DuoLayoutScope.mediaForLayout(context).padding.right,
                ),
              );
      },
    ),
  );
}

class _ChatSurface extends StatelessWidget {
  const _ChatSurface({required this.agent});
  final CommerceAgent agent;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommerceSession, StylistState>(
      bloc: agent,
      builder: (context, _) {
        final surfaceId = agent.latestInlineSurfaceId;
        final entries = agent.conversationEntries;
        final pendingId = agent.pendingInlineSurfaceId;
        final controlsDisabled =
            agent.isBusy || agent.connectionError != null || pendingId != null;
        return Column(
          key: const ValueKey('stylist-conversation'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in entries)
              switch (entry) {
                CommerceUserMessage(:final id, :final text) => Padding(
                  key: ValueKey('user-message-$id'),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: FinalizedUserMessage(text: text),
                ),
                CommerceSurfaceEntry(
                  surfaceId: final entryId,
                  :final textAlreadyVisible,
                ) =>
                  Padding(
                    key: ValueKey('conversation-surface-$entryId'),
                    padding: EdgeInsets.only(
                      bottom:
                          entry == entries.last &&
                              pendingId == null &&
                              !agent.isBusy
                          ? 8
                          : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (entryId != surfaceId)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              context.l10n.previousResponse,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        _ConversationSurface(
                          agent: agent,
                          surfaceId: entryId,
                          inactive: controlsDisabled || entryId != surfaceId,
                          reveal: entryId == surfaceId,
                          textAlreadyVisible: textAlreadyVisible,
                        ),
                      ],
                    ),
                  ),
              },
            if (pendingId != null)
              Padding(
                key: ValueKey('pending-surface-$pendingId'),
                padding: const EdgeInsets.only(bottom: 20),
                child: _ConversationSurface(
                  agent: agent,
                  surfaceId: pendingId,
                  inactive: true,
                  reveal: true,
                ),
              ),
            if (agent.isBusy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        surfaceId == null
                            ? context.l10n.askingStylist
                            : context.l10n.stylistThinking,
                      ),
                    ),
                  ],
                ),
              ),
            if (agent.connectionError != null)
              _ConnectionNotice(
                message: agent.connectionError!,
                onRetry: agent.canRetry ? agent.retryLastTurn : null,
              ),
            if (agent.inputError != null)
              _ConnectionNotice(
                title: context.l10n.updateOutfit,
                message: agent.inputError!,
              ),
            if (agent.connectionNotice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(agent.connectionNotice!),
              ),
          ],
        );
      },
    );
  }
}

class _ConversationSurface extends StatelessWidget {
  const _ConversationSurface({
    required this.agent,
    required this.surfaceId,
    required this.inactive,
    this.reveal = false,
    this.textAlreadyVisible = false,
  });

  final CommerceAgent agent;
  final String surfaceId;
  final bool inactive;
  final bool reveal;
  final bool textAlreadyVisible;

  @override
  Widget build(BuildContext context) => Semantics(
    blockUserActions: inactive,
    child: IgnorePointer(
      ignoring: inactive,
      child: ExcludeFocus(
        excluding: inactive,
        child: StylistSurfaceScope(
          enqueueMessages: reveal && agent.pendingInlineSurfaceId != surfaceId,
          textAlreadyVisible: textAlreadyVisible,
          child: StylistSurfaceMotion(
            surfaceContext: agent.controller.contextFor(surfaceId),
            enabled: reveal && !textAlreadyVisible,
            child: Surface(
              key: ValueKey(surfaceId),
              surfaceContext: agent.controller.contextFor(surfaceId),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.message, this.title, this.onRetry});
  final String message;
  final String? title;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff4f4f5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? context.l10n.stylistUnavailable,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({required this.agent});

  final CommerceAgent agent;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  final textController = TextEditingController();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = textController.text.trim();
    if (text.isEmpty ||
        widget.agent.isBusy ||
        widget.agent.pendingInlineSurfaceId != null ||
        widget.agent.connectionError != null) {
      return;
    }
    textController.clear();
    await widget.agent.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !widget.agent.isBusy &&
        widget.agent.pendingInlineSurfaceId == null &&
        widget.agent.connectionError == null &&
        widget.agent.hasStarted;
    return StylistComposer(
      controller: textController,
      enabled: canSend,
      fieldKey: const ValueKey('stylist-composer'),
      onSubmitted: (_) => _send(),
    );
  }
}

class _DressingPanel extends StatelessWidget {
  const _DressingPanel({
    required this.agent,
    required this.onNewJourney,
    this.inspectionInToolbar = false,
  });

  final CommerceAgent agent;
  final VoidCallback onNewJourney;
  final bool inspectionInToolbar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final experience = _buildExperience(context);
      final split = AdaptivePaneScope.isSplitOf(context);
      final safeRight = DuoLayoutScope.mediaForLayout(context).padding.right;
      final inspector = agent.inspector;
      final showRail = _showRail(context, constraints);
      final fold = DuoLayoutScope.of(context);
      final innerDisplay =
          fold.capabilities.isFoldable && fold.status != HingeStatus.closed;
      return inspector == null
          ? experience
          : CommerceInspectionPane(
              bloc: inspector,
              experience: experience,
              fullScreen: !split,
              showButton: !inspectionInToolbar || split,
              // Compact panes already sit inside the safe area. Split panes
              // extend to the screen edge and must reserve it for this control.
              buttonRightOffset: showRail
                  ? (innerDisplay ? 18 : 12)
                  : split
                  ? safeRight
                  : 0,
              buttonTopOffset: showRail
                  ? _SideRail.closeTop +
                        _SideRail.controlSize +
                        12 +
                        (innerDisplay ? 0 : 12)
                  : null,
              plainButton: showRail,
              buttonForegroundColor:
                  showRail &&
                      innerDisplay &&
                      (AdaptivePaneScope.secondaryBackgroundColorOf(context) ??
                                  Colors.white)
                              .computeLuminance() >=
                          .5
                  ? Colors.black
                  : Colors.white,
              inspectionPadding: EdgeInsets.only(right: safeRight),
            );
    },
  );

  bool _showRail(BuildContext context, BoxConstraints constraints) =>
      agent.hasDressingRoomSurface &&
      AdaptivePaneScope.isSplitOf(context) &&
      constraints.hasBoundedHeight &&
      MediaQuery.sizeOf(context).width >= 900 &&
      constraints.maxWidth - 84 >=
          320 * math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14);

  Widget _buildExperience(
    BuildContext context,
  ) => BlocBuilder<CommerceSession, StylistState>(
    bloc: agent,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final ready =
            agent.hasDressingRoomSurface &&
            agent.controller
                    .contextFor('dressing-room')
                    .definition
                    .value
                    ?.components
                    .containsKey('root') ==
                true;
        final split = AdaptivePaneScope.isSplitOf(context);
        final showRail = ready && _showRail(context, constraints);
        final fold = DuoLayoutScope.of(context);
        final innerDisplay =
            fold.capabilities.isFoldable && fold.status != HingeStatus.closed;
        final book = innerDisplay && fold.isPartiallyOpen;
        final separateRail = innerDisplay && !book;
        final identity = ValueKey(
          ready ? 'dressing-room-ready' : 'dressing-room-pending',
        );
        final room = AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AdaptivePaneLayout.transitionDuration,
          curve: Curves.easeInOutCubic,
          padding: split && !book && (!showRail || separateRail)
              ? const EdgeInsets.symmetric(vertical: 12)
              : EdgeInsets.zero,
          child: _DressingRoomSurface(agent: agent),
        );
        final rail = showRail
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: room),
                  SizedBox(
                    width: 84,
                    child: _SideRail(
                      // Figma's 12/24 gutters align the app controls with the
                      // system status indicator rather than the rail midpoint.
                      controlPadding: innerDisplay
                          ? const EdgeInsets.only(left: 12, right: 24)
                          : EdgeInsets.zero,
                      backgroundColor: innerDisplay
                          ? AdaptivePaneScope.secondaryBackgroundColorOf(
                                  context,
                                ) ??
                                Colors.white
                          : Colors.black,
                      onNewJourney: onNewJourney,
                      bagCount: agent.bagCount,
                      onBag: agent.hasLocalLibrary && !agent.isBusy
                          ? agent.openBag
                          : null,
                    ),
                  ),
                ],
              )
            : null;
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          switchInCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: child.key == identity
                ? animation
                : const AlwaysStoppedAnimation(1),
            child: child,
          ),
          layoutBuilder: (current, previous) => Stack(
            fit: constraints.hasBoundedHeight
                ? StackFit.expand
                : StackFit.loose,
            alignment: Alignment.topLeft,
            children: [
              for (final child in previous)
                ExcludeSemantics(child: IgnorePointer(child: child)),
              ?current,
            ],
          ),
          child: ready
              ? SizedBox(
                  key: identity,
                  width: constraints.maxWidth,
                  child: showRail && innerDisplay
                      ? rail
                      : showRail
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ColoredBox(color: Colors.black, child: rail),
                          ),
                        )
                      : room,
                )
              : SizedBox.shrink(key: identity),
        );
      },
    ),
  );
}

class _DressingRoomSurface extends StatelessWidget {
  const _DressingRoomSurface({required this.agent});

  final CommerceAgent agent;

  @override
  Widget build(BuildContext context) {
    final surface = BlocBuilder<CommerceSession, StylistState>(
      bloc: agent,
      builder: (context, _) {
        if (!agent.hasDressingRoomSurface) return const SizedBox.shrink();
        final inactive =
            agent.isBusy ||
            agent.connectionError != null ||
            agent.pendingInlineSurfaceId != null;
        return Semantics(
          blockUserActions: inactive,
          child: ExcludeFocus(
            excluding: inactive,
            child: IgnorePointer(
              ignoring: inactive,
              child: AnimatedSize(
                key: const ValueKey('dressing-room-resize'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : StylistSurfaceMotion.duration,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topLeft,
                child: Surface(
                  surfaceContext: agent.controller.contextFor('dressing-room'),
                ),
              ),
            ),
          ),
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = AdaptivePaneScope.isSplitOf(context);
        final styled = CommerceDressingRoomStyle(
          dark: true,
          compact: !split,
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          child: surface,
        );
        return constraints.hasBoundedHeight
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  key: const ValueKey('dressing-panel-scroll'),
                  child: styled,
                ),
              )
            : styled;
      },
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.onNewJourney,
    this.showBag = false,
    this.bagCount = 0,
    this.onBag,
    this.showInspect = false,
  });

  final VoidCallback onNewJourney;
  final bool showBag;
  final int bagCount;
  final VoidCallback? onBag;
  final bool showInspect;

  @override
  Widget build(BuildContext context) {
    final split = AdaptivePaneScope.isSplitOf(context);
    final showClose = !split || MediaQuery.sizeOf(context).width < 900;
    return Stack(
      key: const ValueKey('alder-journey-header'),
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: StylistGlassBackdrop(fadeTowardsBottom: true),
          ),
        ),
        Padding(
          padding: split
              ? const EdgeInsets.fromLTRB(32, 32, 32, 24)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Align(
                alignment: split ? Alignment.centerLeft : Alignment.center,
                heightFactor: 1,
                child: const SizedBox(width: 76, child: BrandLockup()),
              ),
              if (showBag && !split)
                Positioned(
                  left: 0,
                  top: -12,
                  bottom: -12,
                  child: FinalizedBagIcon(
                    key: const ValueKey('phone-header-bag'),
                    count: bagCount,
                    onPressed: onBag,
                  ),
                ),
              if (showInspect && !split)
                Positioned(
                  right: 48,
                  top: -12,
                  bottom: -12,
                  child: IconButton(
                    key: const ValueKey('commerce-inspect-button'),
                    onPressed: () => CommerceInspectionPane.inspect(context),
                    icon: const Icon(Icons.data_object, size: 20),
                    tooltip: context.l10n.inspectorInspect,
                  ),
                ),
              if (showClose)
                Positioned(
                  right: 0,
                  top: -12,
                  bottom: -12,
                  child: IconButton(
                    onPressed: onNewJourney,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: context.l10n.newJourney,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideRail extends StatelessWidget {
  static const closeTop = 122.0;
  static const controlSize = 48.0;

  const _SideRail({
    required this.onNewJourney,
    this.bagCount = 0,
    this.onBag,
    this.backgroundColor = Colors.black,
    this.controlPadding = EdgeInsets.zero,
  });

  final VoidCallback onNewJourney;
  final int bagCount;
  final VoidCallback? onBag;
  final Color backgroundColor;
  final EdgeInsets controlPadding;

  @override
  Widget build(BuildContext context) {
    final dark = backgroundColor.computeLuminance() < .5;
    return ColoredBox(
      key: const ValueKey('dressing-room-side-rail'),
      color: backgroundColor,
      child: Padding(
        padding: controlPadding,
        child: Column(
          children: [
            const SizedBox(height: closeTop),
            IconButton(
              onPressed: onNewJourney,
              tooltip: context.l10n.newJourney,
              icon: Icon(
                Icons.close,
                size: 24,
                color: dark ? Colors.white : Colors.black,
              ),
              constraints: const BoxConstraints.tightFor(
                width: controlSize,
                height: controlSize,
              ),
            ),
            const Spacer(),
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                dark ? Colors.white : Colors.black,
                BlendMode.srcIn,
              ),
              child: FinalizedBagIcon(count: bagCount, onPressed: onBag),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Supports an unconnected landing screen without constructing a fake session.
class _SessionBuilder extends StatelessWidget {
  const _SessionBuilder({required this.session, required this.builder});
  final CommerceSession? session;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final value = session;
    if (value == null) return builder(context);
    return BlocBuilder<CommerceSession, StylistState>(
      bloc: value,
      builder: (context, state) => builder(context),
    );
  }
}
