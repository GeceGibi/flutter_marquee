library marqueer;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

part 'controller.dart';
part 'scroll_view.dart';

const _kDefaultStep = 10000.0;

/// Direction types
/// RightToLeft, LeftToRight, TopToBottom, BottomToTop
enum MarqueerDirection {
  /// Right to Left
  rtl,

  /// Left to Right
  ltr,

  /// Top to Bottom
  ttb,

  /// Bottom to Top
  btt,
}

Axis _getAxisForMarqueerDirection(MarqueerDirection direction) {
  return switch (direction) {
    MarqueerDirection.rtl || MarqueerDirection.ltr => Axis.horizontal,
    MarqueerDirection.ttb || MarqueerDirection.btt => Axis.vertical
  };
}

class Marqueer extends StatefulWidget {
  Marqueer({
    required Widget child,
    Widget Function(BuildContext context, int index)? separatorBuilder,
    this.pps = 15.0,
    this.infinity = true,
    this.autoStart = true,
    this.direction = MarqueerDirection.rtl,
    this.interaction = true,
    this.restartAfterInteractionDuration = const Duration(seconds: 3),
    this.restartAfterInteraction = true,
    this.onChangeItemInViewPort,
    this.autoStartAfter = Duration.zero,
    this.onInteraction,
    this.controller,
    this.onStarted,
    this.onStopped,
    this.padding = EdgeInsets.zero,
    this.hitTestBehavior = HitTestBehavior.translucent,
    this.scrollablePointerIgnoring = false,
    this.interactionsChangesAnimationDirection = true,
    super.key,
  })  : assert((() {
          if (autoStartAfter > Duration.zero) {
            return autoStart;
          }

          return true;
        })(),
            'if `autoStartAfter` duration bigger than `zero` then `autoStart` must be `true`'),
        delegate = SliverChildBuilderDelegate(
          (context, index) {
            onChangeItemInViewPort?.call(index);

            if (separatorBuilder == null) {
              return child;
            }

            final children = [child];

            if (direction == MarqueerDirection.rtl) {
              children.add(separatorBuilder(context, index));
            } else {
              children.insert(0, separatorBuilder(context, index));
            }

            return Flex(
              direction: _getAxisForMarqueerDirection(direction),
              mainAxisSize: MainAxisSize.min,
              children: children,
            );
          },
          childCount: infinity ? null : 1,
          addAutomaticKeepAlives: !infinity,
        );

  Marqueer.builder({
    required Widget Function(BuildContext context, int index) itemBuilder,
    Widget Function(BuildContext context, int index)? separatorBuilder,
    int? itemCount,
    this.pps = 15.0,
    this.autoStart = true,
    this.direction = MarqueerDirection.rtl,
    this.interaction = true,
    this.restartAfterInteractionDuration = const Duration(seconds: 3),
    this.restartAfterInteraction = true,
    this.onChangeItemInViewPort,
    this.autoStartAfter = Duration.zero,
    this.onInteraction,
    this.controller,
    this.onStarted,
    this.onStopped,
    this.padding = EdgeInsets.zero,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.scrollablePointerIgnoring = false,
    this.interactionsChangesAnimationDirection = true,
    super.key,
  })  : assert((() {
          if (autoStartAfter > Duration.zero) {
            return autoStart;
          }

          return true;
        })(),
            'if `autoStartAfter` duration bigger than `zero` then `autoStart` must be `true`'),
        infinity = itemCount == null,
        delegate = SliverChildBuilderDelegate(
          (context, index) {
            onChangeItemInViewPort?.call(index);

            final widget = itemBuilder(context, index);

            if (separatorBuilder == null || index + 1 == itemCount) {
              return widget;
            }

            final children = [widget];

            if (direction == MarqueerDirection.rtl) {
              children.add(separatorBuilder(context, index));
            } else {
              children.insert(0, separatorBuilder(context, index));
            }

            return Flex(
              direction: _getAxisForMarqueerDirection(direction),
              children: children,
            );
          },
          childCount: itemCount,
          addAutomaticKeepAlives: itemCount != null,
        );

  final SliverChildDelegate delegate;

  /// Direction
  final MarqueerDirection direction;

  /// List View Padding
  final EdgeInsets padding;

  /// Pixel Per Second
  final double pps;

  /// Interactions
  final bool interaction;

  /// Stop when interaction
  final bool restartAfterInteraction;

  ///
  final bool interactionsChangesAnimationDirection;

  /// Restart delay
  final Duration restartAfterInteractionDuration;

  /// Controller
  final MarqueerController? controller;

  /// auto start
  final bool autoStart;

  /// Auto Start after duration
  final Duration autoStartAfter;

  /// {@macro flutter.widgets.scrollable.hitTestBehavior}
  ///
  /// Defaults to [HitTestBehavior.opaque].
  final HitTestBehavior hitTestBehavior;

  /// Scrollable Widget has default Ignore pointer.
  /// It's causing some gesture bugs, with this prob Scrollable > IgnorePointer is ignoring. :).
  ///
  /// - https://github.com/flutter/flutter/blob/stable/packages/flutter/lib/src/widgets/scrollable.dart#L998
  /// - https://github.com/flutter/flutter/blob/stable/packages/flutter/lib/src/widgets/scrollable.dart#L813
  /// - https://github.com/flutter/flutter/blob/stable/packages/flutter/lib/src/widgets/scroll_context.dart#L60
  final bool scrollablePointerIgnoring;

  ///
  final bool infinity;

  /// callbacks
  final void Function()? onStarted;
  final void Function()? onStopped;
  final void Function()? onInteraction;
  final void Function(int index)? onChangeItemInViewPort;

  @override
  State<Marqueer> createState() => _MarqueerState();
}

class _MarqueerState extends State<Marqueer> {
  final scrollController = ScrollController();

  var animating = false;

  late var interaction = widget.interaction;
  late var direction = widget.direction;

  late var isReverse =
      direction == MarqueerDirection.ltr || direction == MarqueerDirection.btt;

  late var scrollDirection =
      isReverse ? ScrollDirection.reverse : ScrollDirection.forward;

  Timer? timerStarter;
  Timer? timerLoop;
  Timer? timerInteraction;

  Duration run() {
    final position = getNextPosition();
    var distance = (scrollController.offset - position.abs()).abs();

    if (distance <= 0) {
      distance = position.abs();
    }

    final duration = Duration(
      milliseconds: ((distance / widget.pps) * 1000).round(),
    );

    scrollController.animateTo(
      position,
      duration: duration,
      curve: Curves.linear,
    );

    if (widget.scrollablePointerIgnoring) {
      _searchIgnorePointer(context.findRenderObject());
    }

    return duration;
  }

  void start() {
    widget.onStarted?.call();
    createLoop();
  }

  void forward() {
    scrollDirection = ScrollDirection.reverse;
    stop();
    start();
  }

  void backward() {
    scrollDirection = ScrollDirection.forward;
    stop();
    start();
  }

  Future<void> createLoop() async {
    final duration = run();

    timerLoop?.cancel();
    timerLoop = Timer(duration, createLoop);
  }

  void stop() {
    if (!mounted) {
      return;
    }

    scrollController.jumpTo(scrollController.offset);

    timerLoop?.cancel();
    timerStarter?.cancel();
    timerInteraction?.cancel();
    widget.onStopped?.call();
  }

  double getNextPosition() {
    final ScrollController(:offset, :position) = scrollController;
    final ScrollPosition(:maxScrollExtent) = position;

    if (offset == 0) {
      if (!widget.infinity && _kDefaultStep >= maxScrollExtent) {
        return maxScrollExtent;
      }

      return _kDefaultStep;
    }

    switch (scrollDirection) {
      case ScrollDirection.idle:
        return _kDefaultStep;

      case ScrollDirection.forward:
        final next = offset - _kDefaultStep;

        if (next <= 0) {
          scrollDirection = ScrollDirection.reverse;
          return 0;
        }

        return next;

      case ScrollDirection.reverse:
        final next = offset + _kDefaultStep;

        if (next >= maxScrollExtent) {
          scrollDirection = ScrollDirection.forward;
          return maxScrollExtent;
        }

        return next;
    }
  }

  void interactionEnabled(bool enabled) {
    if (interaction == enabled) {
      return;
    }

    timerInteraction?.cancel();
    interaction = enabled;
    setState(() {});
  }

  void onPointerUpHandler(PointerUpEvent event) {
    if (!widget.restartAfterInteraction || !widget.interaction) {
      return;
    }

    /// Wait for scroll animation end
    timerInteraction = Timer(widget.restartAfterInteractionDuration, start);
  }

  void onPointerDownHandler(PointerDownEvent event) {
    widget.onInteraction?.call();

    timerInteraction?.cancel();
    timerLoop?.cancel();
  }

  void _searchIgnorePointer(RenderObject? renderObject) {
    if (renderObject == null) {
      return;
    }

    renderObject.visitChildren((child) {
      if (child is RenderIgnorePointer) {
        child.ignoring = false;
      } else {
        _searchIgnorePointer(child);
      }
    });
  }

  void addListener() {
    if (!widget.interactionsChangesAnimationDirection) {
      return;
    }

    scrollController.addListener(() {
      final ScrollPosition(:userScrollDirection) = scrollController.position;

      if (scrollDirection == userScrollDirection ||
          userScrollDirection == ScrollDirection.idle) {
        return;
      }

      scrollDirection = userScrollDirection;
    });
  }

  @override
  void setState(VoidCallback fn) {
    if (!mounted) {
      return;
    }

    super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);

    /// Wait for the rendering end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoStart) {
        timerStarter = Timer(widget.autoStartAfter, start);
      }

      addListener();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();

    timerLoop?.cancel();
    timerStarter?.cancel();
    timerInteraction?.cancel();
    widget.controller?._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = direction == MarqueerDirection.btt ||
        direction == MarqueerDirection.ttb;

    final physics = interaction
        ? const BouncingScrollPhysics()
        : const NeverScrollableScrollPhysics();

    return Listener(
      behavior: widget.hitTestBehavior,
      onPointerDown: onPointerDownHandler,
      onPointerUp: onPointerUpHandler,
      child: _MarqueerScrollView(
        widget.delegate,
        physics: physics,
        reverse: isReverse,
        padding: widget.padding,
        controller: scrollController,
        scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
        semanticChildCount: widget.delegate.estimatedChildCount,
        hitTestBehavior: widget.hitTestBehavior,
      ),
    );
  }
}
