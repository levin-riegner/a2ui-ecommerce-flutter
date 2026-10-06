import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

import 'agent/commerce_agent.dart';
import 'agent/model_connection.dart';
import 'agent/genkit_agent.dart';
import 'catalog/commerce_examples.dart';
import 'catalog/commerce_components.dart';
import 'catalog/finalized_component_gallery.dart';
import 'catalog/finalized_screen_gallery.dart';
import 'catalog/finalized_shared_components.dart';
import 'data/models.dart';
import 'layout/adaptive_page.dart';
import 'layout/adaptive_pane_layout.dart';
import 'layout/duo_layout_adapter.dart';
import 'layout/stylist_composer.dart';
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
      title: 'A2UI Flutter Commerce',
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
    body: AdaptivePaneLayout(
      compactSecondaryFirst: false,
      secondaryScrollable: false,
      secondaryPadding: EdgeInsets.zero,
      panePadding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
      header: const Padding(
        padding: EdgeInsets.fromLTRB(32, 24, 32, 16),
        child: _BrandLockup(),
      ),
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where are you going?',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w400,
              height: 1.2,
              letterSpacing: -.75,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell me the occasion, where it is and roughly what you’d like to spend. I’ll pull the whole look together from what we carry, and you can change anything as we go.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.4,
              color: Colors.black.withValues(alpha: .75),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          if (onSelect != null && onStartBrief == null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final journey in DemoJourney.values)
                  ActionChip(
                    label: Text(journey.title),
                    onPressed: isBusy ? null : () => onSelect!(journey),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'HERE ARE SOME EXAMPLES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 1,
              color: Colors.black.withValues(alpha: .4),
            ),
          ),
          const SizedBox(height: 8),
          for (final example in _occasionExamples) ...[
            _OccasionSuggestion(
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
            const SizedBox(height: 8),
          ],
          if (onStartBrief != null) ...[
            const SizedBox(height: 16),
            Text(
              'Preset journeys',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final journey in DemoJourney.values)
                  ActionChip(
                    label: Text(journey.title),
                    onPressed: isBusy ? null : () => onSelect!(journey),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
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
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
        child: onStartBrief != null
            ? _CustomBriefEntry(onStart: onStartBrief!, isBusy: isBusy)
            : onConnect != null
            ? FilledButton(
                onPressed: onConnect,
                child: const Text('Connect your model'),
              )
            : const SizedBox.shrink(),
      ),
    ),
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
    color: const Color(0xfff3f3f3),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset('assets/images/occasions/suggestion-sparkle.svg'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 16, height: 1.4, letterSpacing: -.25),
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
    child: Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(6, 4, 3, 5),
      child: Text(
        'ALDER',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 4,
          height: 1.1,
        ),
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
      final columnWidth = (width - 8) / 2.4;
      return SizedBox(
        height: height,
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
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
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
    body: AdaptivePaneLayout(
      primary: _ChatSurface(agent: agent),
      secondaryBackgroundColor: Colors.black,
      secondaryBackgroundOnlyInBookMode: true,
      secondary: _DressingPanel(agent: agent),
      header: _MobileHeader(onNewJourney: onNewJourney),
      footer: _ChatComposer(
        agent: agent,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      ),
      rail: _SideRail(onNewJourney: onNewJourney),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            if (surfaceId != null)
              IgnorePointer(
                ignoring: agent.isBusy || agent.connectionError != null,
                child: ExcludeFocus(
                  excluding: agent.isBusy || agent.connectionError != null,
                  child: Surface(
                    key: ValueKey(surfaceId),
                    surfaceContext: agent.controller.contextFor(surfaceId),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
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
  const _ChatComposer({required this.agent, this.padding = EdgeInsets.zero});

  final CommerceAgent agent;
  final EdgeInsets padding;

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
        widget.agent.connectionError == null &&
        widget.agent.latestInlineSurfaceId != null;
    return StylistComposer(
      controller: textController,
      enabled: canSend,
      fieldKey: const ValueKey('stylist-composer'),
      padding: widget.padding,
      onSubmitted: (_) => _send(),
    );
  }
}

class _DressingPanel extends StatelessWidget {
  const _DressingPanel({required this.agent});

  final CommerceAgent agent;

  @override
  Widget build(BuildContext context) {
    final backdropDark =
        (AdaptivePaneScope.secondaryBackgroundColorOf(context) ?? Colors.white)
            .computeLuminance() <
        .5;
    final surface = AnimatedBuilder(
      animation: agent,
      builder: (context, _) {
        if (!agent.hasDressingRoomSurface) return const SizedBox.shrink();
        return ExcludeFocus(
          excluding: agent.isBusy || agent.connectionError != null,
          child: IgnorePointer(
            ignoring: agent.isBusy || agent.connectionError != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  key: const ValueKey('dressing-room-resize'),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AdaptivePaneLayout.transitionDuration,
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topLeft,
                  child: Surface(
                    surfaceContext: agent.controller.contextFor(
                      'dressing-room',
                    ),
                  ),
                ),
                if (agent.hasSelectedProductsSurface) ...[
                  const SizedBox(height: 12),
                  CommerceDressingRoomStyle(
                    dark: backdropDark,
                    child: Surface(
                      key: const ValueKey('selected-pieces-section'),
                      surfaceContext: agent.controller.contextFor(
                        'selected-products',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    return CommerceDressingRoomStyle(
      dark: true,
      compact: !AdaptivePaneScope.isSplitOf(context),
      child: surface,
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onNewJourney});

  final VoidCallback onNewJourney;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onNewJourney,
            icon: const Icon(Icons.close, size: 24),
            tooltip: 'New journey',
          ),
          const SizedBox(width: 4),
          const Expanded(child: _BrandLockup()),
        ],
      ),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
