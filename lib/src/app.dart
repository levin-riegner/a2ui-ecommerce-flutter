import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:foldable/foldable.dart';

import 'agent/commerce_agent.dart';
import 'agent/conversation_entry.dart';
import 'agent/model_connection.dart';
import 'agent/genkit_agent.dart';
import 'catalog/commerce_examples.dart';
import 'catalog/commerce_components.dart';
import 'catalog/finalized_left_components.dart';
import 'catalog/finalized_component_gallery.dart';
import 'catalog/finalized_screen_gallery.dart';
import 'catalog/finalized_shared_components.dart';
import 'data/models.dart';
import 'layout/adaptive_page.dart';
import 'layout/adaptive_pane_layout.dart';
import 'layout/duo_layout_adapter.dart';
import 'layout/stylist_composer.dart';
import 'layout/stylist_layout.dart';
import 'layout/stylist_surface_motion.dart';
import 'theme.dart';

const _basicComponentGalleryNames = <String>[
  'Button',
  'Card',
  'CheckBox',
  'Column',
  'ChoicePicker',
  'DateTimeInput',
  'Divider',
  'Icon',
  'List',
  'Modal',
  'Row',
  'Slider',
  'Tabs',
  'Text',
  'TextField',
];

class ReferenceApp extends StatefulWidget {
  const ReferenceApp({super.key, this.agent, this.connectionClient});

  /// Injection for tests and component previews. The app disposes this agent.
  final CommerceAgent? agent;
  final http.Client? connectionClient;

  @override
  State<ReferenceApp> createState() => _ReferenceAppState();
}

class _ReferenceAppState extends State<ReferenceApp> {
  CommerceAgent? agent;

  @override
  void initState() {
    super.initState();
    agent = widget.agent;
  }

  @override
  void dispose() {
    agent?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alder',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => DuoLayoutAdapter(child: child!),
      home: _AppHome(
        key: ObjectKey(agent),
        agent: agent,
        connectionClient: widget.connectionClient,
        onConnected: (value) => setState(() => agent = value),
        onDisconnect: widget.agent == null && agent != null
            ? () {
                final previous = agent;
                setState(() => agent = null);
                previous?.dispose();
              }
            : null,
      ),
    );
  }
}

class _AppHome extends StatefulWidget {
  const _AppHome({
    super.key,
    required this.agent,
    required this.onConnected,
    this.onDisconnect,
    this.connectionClient,
  });

  final CommerceAgent? agent;
  final ValueChanged<GenkitAgent> onConnected;
  final VoidCallback? onDisconnect;
  final http.Client? connectionClient;

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  bool showGallery = false;
  bool showStartScreen = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    return AnimatedBuilder(
      animation: agent ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) {
        if (showGallery) {
          return _ComponentGallery(
            onBack: () => setState(() => showGallery = false),
          );
        }
        if (agent == null || showStartScreen || !agent.hasStarted) {
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
                            client: widget.connectionClient,
                            onConnected: (value) {
                              Navigator.of(dialogContext).pop();
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
                : (journey) {
                    setState(() => showStartScreen = false);
                    return agent.startJourney(journey);
                  },
            onStartBrief: agent?.canStartBrief == true
                ? (message) {
                    setState(() => showStartScreen = false);
                    return agent!.startBrief(message);
                  }
                : null,
            isBusy: agent?.isBusy ?? false,
            onOpenGallery: () => setState(() => showGallery = true),
          );
        }
        return _ResponsiveShell(
          agent: agent,
          onNewJourney: () => setState(() => showStartScreen = true),
        );
      },
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
        final innerLandscape =
            fold.status == HingeStatus.fullyOpen &&
            constraints.maxWidth > constraints.maxHeight;
        final threadMinHeight = math.max(
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
          extendPrimaryIntoBottomPadding: innerLandscape,
          overlayHeader: true,
          overlayFooter: onStartBrief != null,
          secondaryScrollable: false,
          extendSecondaryToEdges: true,
          secondaryBackgroundColor: Colors.black,
          secondaryPadding: EdgeInsets.zero,
          panePadding: closed
              ? const EdgeInsets.fromLTRB(16, 8, 8, 8)
              : const EdgeInsets.fromLTRB(32, 0, 32, 8),
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
                  child: const _BrandLockup(),
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
                      label: 'HERE ARE SOME EXAMPLES',
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
                          constraints: const BoxConstraints(maxWidth: 400),
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
                label: const Text('Explore component catalog'),
              ),
              if (onDisconnect != null)
                TextButton(
                  onPressed: isBusy ? null : onDisconnect,
                  child: const Text('Disconnect model'),
                ),
            ],
          ),
          secondary: const _MosaicPreview(),
          footer: onStartBrief != null
              ? StylistComposerDock(
                  horizontalPadding: 32,
                  padding: closed
                      ? const EdgeInsets.fromLTRB(16, 8, 8, 0)
                      : const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _CustomBriefEntry(
                    onStart: onStartBrief!,
                    isBusy: isBusy,
                  ),
                )
              : Padding(
                  padding: closed
                      ? const EdgeInsets.fromLTRB(16, 16, 8, 0)
                      : const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: onConnect != null
                      ? FilledButton(
                          onPressed: onConnect,
                          child: const Text('Connect your model'),
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
        'Where are you going?',
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
        'Tell me the occasion, where it is and roughly what you’d like to spend. I’ll pull the whole look together from what we carry, and you can change anything as we go.',
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
    message: 'A summer wedding in Lisbon in late June — outdoor ceremony, cocktail dress code, around €1,200 for the whole outfit',
  ),
  (
    journey: DemoJourney.paris,
    message: 'Anniversary dinner at a smart restaurant in Paris in October, black tie optional, about €1,500',
  ),
  (
    journey: DemoJourney.berlin,
    message: 'First day at a creative agency in Berlin in September. Smart casual, nothing corporate, under €800',
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
    fieldLabel: 'Your occasion',
    submitLabel: 'Start my look',
    onSubmitted: (_) => _submit(),
  );
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    heightFactor: 1,
    child: Semantics(
      label: 'ALDER',
      image: true,
      child: SvgPicture.asset(
        'assets/images/occasions/alder-wordmark.svg',
        excludeFromSemantics: true,
      ),
    ),
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
                            Image.asset(
                              'assets/images/occasions/start-${number.toString().padLeft(2, '0')}.png',
                              width: columnWidth,
                              height: columnWidth * 4 / 3,
                              fit: BoxFit.cover,
                              alignment: number == 6
                                  ? Alignment.topCenter
                                  : Alignment.center,
                              excludeFromSemantics: true,
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

class _ComponentGallery extends StatelessWidget {
  const _ComponentGallery({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdaptivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                const Expanded(child: _BrandLockup()),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              'Catalog components',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'A visual index of the commerce vocabulary available to A2UI surfaces. Each custom item has a schema, a Flutter builder, and a fixture-backed interaction path.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: const Color(0xff71717a), height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              '9 commerce components · 15 GenUI basic components',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FinalizedComponentGallery(),
                ),
              ),
              child: const Text('Finalized Figma components'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FinalizedScreenGallery(),
                ),
              ),
              child: const Text('Finalized Figma screens'),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth < 680
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final example in commerceComponentExamples)
                      _GalleryTile(
                        width: tileWidth,
                        name: example.name,
                        description: example.description,
                        preview: example.previewBuilder(context),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            Text(
              'GenUI basic components',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'These primitives are available from the base catalog and can be composed before adding a custom schema.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _basicComponentGalleryNames)
                  Chip(
                    avatar: const Icon(Icons.widgets_outlined, size: 16),
                    label: Text(name),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'Basic components remain available through the GenUI catalog. Add a custom item only when a schema and reusable interaction are clearer than composing existing primitives.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.width,
    required this.name,
    required this.description,
    required this.preview,
  });

  final double width;
  final String name;
  final String description;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe4e4e7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xff71717a)),
            ),
            const SizedBox(height: 16),
            preview,
          ],
        ),
      ),
    );
  }
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
        final innerLandscape =
            fold.status == HingeStatus.fullyOpen &&
            constraints.maxWidth > constraints.maxHeight;
        final gutter = cover || constraints.maxWidth < 600
            ? StylistLayout.compactGutter
            : StylistLayout.gutter;
        return AdaptivePaneLayout(
          overlayFooter: true,
          overlayHeader: true,
          primaryBottomInset: StylistLayout.composerBottomClearance,
          extendPrimaryIntoBottomPadding: innerLandscape,
          panePadding: EdgeInsets.fromLTRB(gutter, 32, gutter, 8),
          secondaryPadding: const EdgeInsets.symmetric(vertical: 12),
          compactSecondaryPadding: const EdgeInsets.symmetric(horizontal: 16),
          secondaryScrollable: false,
          extendSecondaryToEdges: true,
          compactPaneGap: 32,
          reserveRailInExtendedSecondary: true,
          followPrimaryEnd: true,
          stackSecondaryInPortrait: !cover && agent.hasDressingRoomSurface,
          railWidth: 84,
          primary: _ChatSurface(agent: agent),
          secondaryBackgroundColor: Colors.black,
          secondaryBackgroundOnlyInBookMode: true,
          secondary: _DressingPanel(agent: agent),
          header: _MobileHeader(onNewJourney: onNewJourney),
          footer: StylistComposerDock(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ChatComposer(agent: agent),
          ),
          rail: _SideRail(onNewJourney: onNewJourney),
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
    return AnimatedBuilder(
      animation: agent,
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
                CommerceSurfaceEntry(surfaceId: final entryId) => Padding(
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
                            'Previous response',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      _ConversationSurface(
                        agent: agent,
                        surfaceId: entryId,
                        inactive: controlsDisabled || entryId != surfaceId,
                        reveal: entryId == surfaceId,
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
                            ? 'Asking your stylist…'
                            : 'Your stylist is thinking…',
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
  });

  final CommerceAgent agent;
  final String surfaceId;
  final bool inactive;
  final bool reveal;

  @override
  Widget build(BuildContext context) => Semantics(
    blockUserActions: inactive,
    child: IgnorePointer(
      ignoring: inactive,
      child: ExcludeFocus(
        excluding: inactive,
        child: StylistSurfaceScope(
          child: StylistSurfaceMotion(
            surfaceContext: agent.controller.contextFor(surfaceId),
            enabled: reveal,
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
  const _ConnectionNotice({required this.message, this.onRetry});
  final String message;
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
            'Stylist unavailable',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
    await widget.agent.conversation.sendRequest(ChatMessage.user(text));
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !widget.agent.isBusy &&
        widget.agent.pendingInlineSurfaceId == null &&
        widget.agent.connectionError == null &&
        widget.agent.latestInlineSurfaceId != null;
    return StylistComposer(
      controller: textController,
      enabled: canSend,
      fieldKey: const ValueKey('stylist-composer'),
      onSubmitted: (_) => _send(),
    );
  }
}

class _DressingPanel extends StatelessWidget {
  const _DressingPanel({required this.agent});

  final CommerceAgent agent;

  @override
  Widget build(BuildContext context) {
    final surface = AnimatedBuilder(
      animation: agent,
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
  const _MobileHeader({required this.onNewJourney});

  final VoidCallback onNewJourney;

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
            alignment: Alignment.center,
            children: [
              Align(
                alignment: split ? Alignment.centerLeft : Alignment.center,
                heightFactor: 1,
                child: const SizedBox(width: 76, child: _BrandLockup()),
              ),
              if (showClose)
                Positioned(
                  right: 0,
                  top: -12,
                  bottom: -12,
                  child: IconButton(
                    onPressed: onNewJourney,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'New journey',
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
  const _SideRail({required this.onNewJourney});

  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) {
    final background =
        AdaptivePaneScope.secondaryBackgroundColorOf(context) ?? Colors.white;
    final dark = background.computeLuminance() < .5;
    return ColoredBox(
      color: background,
      child: Column(
        children: [
          const SizedBox(height: 122),
          IconButton(
            onPressed: onNewJourney,
            tooltip: 'New journey',
            icon: Icon(
              Icons.close,
              size: 24,
              color: dark ? Colors.white : Colors.black,
            ),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
          const Spacer(),
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              dark ? Colors.white54 : Colors.black54,
              BlendMode.srcIn,
            ),
            child: const FinalizedBagIcon(count: 0),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
