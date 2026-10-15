import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';

import '../agent/commerce_agent.dart';
import '../catalog/finalized_right_components.dart';
import '../catalog/finalized_shared_components.dart';

/// Presents the current host-owned bag over both panes without moving the chat.
/// Actions still go through the current GenUI surface and its runtime guards.
class StylistBagOverlay extends StatefulWidget {
  const StylistBagOverlay({
    super.key,
    required this.agent,
    required this.child,
  });

  final CommerceAgent agent;
  final Widget child;

  @override
  State<StylistBagOverlay> createState() => _StylistBagOverlayState();
}

class _StylistBagOverlayState extends State<StylistBagOverlay> {
  String? _dismissedSurfaceId;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final child = widget.child;
    final id = agent.latestInlineSurfaceId;
    final source = id == null ? null : agent.controller.contextFor(id);
    final components = source?.definition.value?.components;
    final bag = components?['demo-bag'];
    final open = bag != null && id != _dismissedSurfaceId;
    final data = {
      ...?bag?.properties,
      'items': bag == null
          ? const []
          : source?.dataModel.getValue<List<Object?>>(DataPath('/bagItems')) ??
                [],
    };
    void dispatch(Object? action, [Map<String, Object?> extra = const {}]) {
      if (agent.isBusy || agent.connectionError != null) return;
      final event = action is Map ? action['event'] : null;
      if (event is! Map || event['name'] is! String) return;
      source?.handleUiEvent(
        UserActionEvent(
          name: event['name'] as String,
          sourceComponentId: 'demo-bag',
          context: {
            if (event['context'] is Map)
              ...Map<String, Object?>.from(event['context'] as Map),
            ...extra,
          },
        ),
      );
    }

    void close() {
      if (agent.isBusy) return;
      setState(() => _dismissedSurfaceId = id);
      dispatch(data['closeAction']);
    }

    final toastData = components?['library-toast']?.properties;
    final toast =
        (toastData?['action'] as Map?)?['event']?['name'] == 'restore_bag_item'
        ? toastData
        : null;

    return PopScope(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: open,
            child: ExcludeSemantics(
              excluding: open,
              child: IgnorePointer(ignoring: open, child: child),
            ),
          ),
          if (open)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              builder: (_, value, child) =>
                  Opacity(opacity: value, child: child),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: ModalBarrier(
                      key: const ValueKey('bag-modal-barrier'),
                      color: Colors.black.withValues(alpha: .8),
                      dismissible: !agent.isBusy,
                      onDismiss: close,
                      semanticsLabel: 'Close bag',
                    ),
                  ),
                  SafeArea(
                    left: false,
                    right: false,
                    child: Shortcuts(
                      shortcuts: const {
                        SingleActivator(LogicalKeyboardKey.escape):
                            DismissIntent(),
                      },
                      child: Actions(
                        actions: {
                          DismissIntent: CallbackAction<DismissIntent>(
                            onInvoke: (_) {
                              close();
                              return null;
                            },
                          ),
                        },
                        child: FocusScope(
                          autofocus: true,
                          child: Dialog(
                            key: const ValueKey('stylist-bag-dialog'),
                            backgroundColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                            elevation: 0,
                            insetPadding: const EdgeInsets.all(24),
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Flexible(
                                  child: AbsorbPointer(
                                    absorbing: agent.isBusy,
                                    child: FinalizedBagPreview(
                                      data: data,
                                      onAction: (key, extra) =>
                                          dispatch(data[key], extra),
                                    ),
                                  ),
                                ),
                                if (agent.inputError ?? agent.connectionError
                                    case final String error)
                                  Material(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(error),
                                    ),
                                  ),
                                if (toast != null) ...[
                                  const SizedBox(height: 8),
                                  FinalizedToast(
                                    message: toast['message']?.toString() ?? '',
                                    actionLabel:
                                        toast['actionLabel']?.toString() ?? '',
                                    onPressed: agent.isBusy
                                        ? null
                                        : () => dispatch(toast['action']),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
