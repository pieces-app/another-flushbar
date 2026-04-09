import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'flushbar.dart';

class FlushbarRoute<T> extends OverlayRoute<T> {
  final Flushbar flushbar;
  final Builder _builder;
  final Completer<T> _transitionCompleter = Completer<T>();
  final FlushbarStatusCallback? _onStatusChanged;

  Animation<double>? _filterBlurAnimation;
  Animation<Color?>? _filterColorAnimation;
  Animation<Offset>? _slideAnimation;
  Alignment? _initialAlignment;
  Alignment? _endAlignment;
  Offset? _initialSlideOffset;
  Offset? _endSlideOffset;
  bool _wasDismissedBySwipe = false;
  Timer? _timer;
  T? _result;
  FlushbarStatus? currentStatus;

  FlushbarRoute({
    required this.flushbar,
    super.settings,
  })  : _builder = Builder(builder: (BuildContext innerContext) => flushbar),
        _onStatusChanged = flushbar.onStatusChanged {
    _configureAlignment(flushbar.flushbarPosition);
    _configureSlideOffset();
  }

  void _configureAlignment(FlushbarPosition flushbarPosition) {
    // First, determine the end alignment based on position
    switch (flushbar.flushbarPosition) {
      case FlushbarPosition.TOP:
        _endAlignment = flushbar.endOffset != null
            ? const Alignment(-1.0, -1.0) + Alignment(flushbar.endOffset!.dx, flushbar.endOffset!.dy)
            : const Alignment(-1.0, -1.0);
        break;
      case FlushbarPosition.BOTTOM:
        _endAlignment = flushbar.endOffset != null
            ? const Alignment(-1.0, 1.0) + Alignment(flushbar.endOffset!.dx, flushbar.endOffset!.dy)
            : const Alignment(-1.0, 1.0);
        break;
      case FlushbarPosition.BOTTOM_RIGHT:
        _endAlignment = flushbar.endOffset != null
            ? const Alignment(1.0, 1.0) + Alignment(flushbar.endOffset!.dx, flushbar.endOffset!.dy)
            : const Alignment(1.0, 1.0);
        break;
      case FlushbarPosition.TOP_RIGHT:
        _endAlignment = flushbar.endOffset != null
            ? const Alignment(1.0, -1.0) + Alignment(flushbar.endOffset!.dx, flushbar.endOffset!.dy)
            : const Alignment(1.0, -1.0);
        break;
    }

    // Then, determine the initial alignment based on slide direction
    switch (flushbar.slideDirection) {
      case FlushbarSlideDirection.RIGHT_TO_LEFT:
        // Start off-screen to the right, same Y as end position
        _initialAlignment = Alignment(_endAlignment!.x + 2.0, _endAlignment!.y);
        break;
      case FlushbarSlideDirection.LEFT_TO_RIGHT:
        // Start off-screen to the left, same Y as end position
        _initialAlignment = Alignment(_endAlignment!.x - 2.0, _endAlignment!.y);
        break;
      case FlushbarSlideDirection.TOP_TO_BOTTOM:
        // Start off-screen above, same X as end position
        _initialAlignment = Alignment(_endAlignment!.x, _endAlignment!.y - 2.0);
        break;
      case FlushbarSlideDirection.BOTTOM_TO_TOP:
        // Start off-screen below, same X as end position
        _initialAlignment = Alignment(_endAlignment!.x, _endAlignment!.y + 2.0);
        break;
      case FlushbarSlideDirection.DEFAULT:
        // Use default behavior based on position (vertical animation)
        switch (flushbar.flushbarPosition) {
          case FlushbarPosition.TOP:
          case FlushbarPosition.TOP_RIGHT:
            _initialAlignment = Alignment(_endAlignment!.x, -2.0);
            break;
          case FlushbarPosition.BOTTOM:
          case FlushbarPosition.BOTTOM_RIGHT:
            _initialAlignment = Alignment(_endAlignment!.x, 2.0);
            break;
        }
        break;
    }
  }

  void _configureSlideOffset() {
    // Configure slide animation offsets based on slideDirection
    switch (flushbar.slideDirection) {
      case FlushbarSlideDirection.RIGHT_TO_LEFT:
        _initialSlideOffset = const Offset(1.0, 0.0);
        _endSlideOffset = Offset.zero;
        break;
      case FlushbarSlideDirection.LEFT_TO_RIGHT:
        _initialSlideOffset = const Offset(-1.0, 0.0);
        _endSlideOffset = Offset.zero;
        break;
      case FlushbarSlideDirection.TOP_TO_BOTTOM:
        _initialSlideOffset = const Offset(0.0, -1.0);
        _endSlideOffset = Offset.zero;
        break;
      case FlushbarSlideDirection.BOTTOM_TO_TOP:
        _initialSlideOffset = const Offset(0.0, 1.0);
        _endSlideOffset = Offset.zero;
        break;
      case FlushbarSlideDirection.DEFAULT:
        // Use default behavior based on position (vertical animation)
        switch (flushbar.flushbarPosition) {
          case FlushbarPosition.TOP:
          case FlushbarPosition.TOP_RIGHT:
            _initialSlideOffset = const Offset(0.0, -1.0);
            _endSlideOffset = Offset.zero;
            break;
          case FlushbarPosition.BOTTOM:
          case FlushbarPosition.BOTTOM_RIGHT:
            _initialSlideOffset = const Offset(0.0, 1.0);
            _endSlideOffset = Offset.zero;
            break;
        }
        break;
    }
  }

  Future<T> get completed => _transitionCompleter.future;

  bool get opaque => false;

  @override
  Future<RoutePopDisposition> willPop() {
    if (!flushbar.isDismissible &&
        ((flushbar.duration == null) || (flushbar.duration != null && _timer?.isActive == true))) {
      return Future.value(RoutePopDisposition.doNotPop);
    }

    return Future.value(RoutePopDisposition.pop);
  }

  @override
  Iterable<OverlayEntry> createOverlayEntries() {
    final overlays = <OverlayEntry>[];

    if (flushbar.blockBackgroundInteraction) {
      overlays.add(
        OverlayEntry(
            builder: (BuildContext context) {
              return Listener(
                onPointerDown: flushbar.isDismissible ? (_) => flushbar.dismiss() : null,
                child: _createBackgroundOverlay(),
              );
            },
            maintainState: false,
            opaque: opaque),
      );
    }

    Widget child = flushbar.isDismissible ? _getDismissibleFlushbar(_builder) : _getFlushbar();

    if (flushbar.safeArea) {
      child = SafeArea(child: child);
    }

    overlays.add(
      OverlayEntry(
          builder: (BuildContext context) {
            final Widget annotatedChild = Semantics(
              focused: false,
              container: true,
              explicitChildNodes: true,
              child: Align(
                alignment: _endAlignment!,
                child: SlideTransition(
                  position: _slideAnimation!,
                  child: child,
                ),
              ),
            );
            return annotatedChild;
          },
          maintainState: false,
          opaque: opaque),
    );

    return overlays;
  }

  Widget _createBackgroundOverlay() {
    if (_filterBlurAnimation != null && _filterColorAnimation != null) {
      return AnimatedBuilder(
        animation: _filterBlurAnimation!,
        builder: (context, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _filterBlurAnimation!.value, sigmaY: _filterBlurAnimation!.value),
            child: Container(
              constraints: const BoxConstraints.expand(),
              color: _filterColorAnimation!.value,
            ),
          );
        },
      );
    }

    if (_filterBlurAnimation != null) {
      return AnimatedBuilder(
        animation: _filterBlurAnimation!,
        builder: (context, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _filterBlurAnimation!.value, sigmaY: _filterBlurAnimation!.value),
            child: Container(
              constraints: const BoxConstraints.expand(),
              color: Colors.transparent,
            ),
          );
        },
      );
    }

    if (_filterColorAnimation != null) {
      AnimatedBuilder(
        animation: _filterColorAnimation!,
        builder: (context, child) {
          return Container(
            constraints: const BoxConstraints.expand(),
            color: _filterColorAnimation!.value,
          );
        },
      );
    }

    return Container(
      constraints: const BoxConstraints.expand(),
      color: Colors.transparent,
    );
  }

  /// This string is a workaround until Dismissible supports a returning item
  String dismissibleKeyGen = '';

  Widget _getDismissibleFlushbar(Widget child) {
    return Dismissible(
      direction: _getDismissDirection(),
      resizeDuration: null,
      confirmDismiss: (_) {
        if (currentStatus == FlushbarStatus.IS_APPEARING || currentStatus == FlushbarStatus.IS_HIDING) {
          return Future.value(false);
        }
        return Future.value(true);
      },
      key: Key(dismissibleKeyGen),
      onDismissed: (_) {
        dismissibleKeyGen += '1';
        _cancelTimer();
        _wasDismissedBySwipe = true;

        if (isCurrent) {
          navigator!.pop();
        } else {
          navigator!.removeRoute(this);
        }
      },
      child: _getFlushbar(),
    );
  }

  DismissDirection _getDismissDirection() {
    if (flushbar.dismissDirection == FlushbarDismissDirection.HORIZONTAL) {
      return DismissDirection.horizontal;
    } else {
      if (flushbar.flushbarPosition == FlushbarPosition.TOP ||
          flushbar.flushbarPosition == FlushbarPosition.TOP_RIGHT) {
        return DismissDirection.up;
      } else {
        return DismissDirection.down;
      }
    }
  }

  Widget _getFlushbar() {
    return Container(
      margin: flushbar.margin,
      child: _builder,
    );
  }

  @override
  bool get finishedWhenPopped => _controller!.status == AnimationStatus.dismissed;

  /// The animation that drives the route's transition and the previous route's
  /// forward transition.
  Animation<Alignment>? get animation => _animation;
  Animation<Alignment>? _animation;

  /// The animation controller that the route uses to drive the transitions.
  ///
  /// The animation itself is exposed by the [animation] property.
  @protected
  AnimationController? get controller => _controller;
  AnimationController? _controller;

  /// Called to create the animation controller that will drive the transitions to
  /// this route from the previous one, and back to the previous route from this
  /// one.
  AnimationController createAnimationController() {
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    assert(flushbar.animationDuration >= Duration.zero);
    return AnimationController(
      duration: flushbar.animationDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  /// Called to create the animation that exposes the current progress of
  /// the transition controlled by the animation controller created by
  /// [createAnimationController()].
  Animation<Alignment> createAnimation() {
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    assert(_controller != null);
    return AlignmentTween(begin: _initialAlignment, end: _endAlignment).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: flushbar.forwardAnimationCurve,
        reverseCurve: flushbar.reverseAnimationCurve,
      ),
    );
  }

  /// Creates the slide animation for translating the flushbar position.
  Animation<Offset> createSlideAnimation() {
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    assert(_controller != null);
    return Tween<Offset>(begin: _initialSlideOffset, end: _endSlideOffset).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: flushbar.forwardAnimationCurve,
        reverseCurve: flushbar.reverseAnimationCurve,
      ),
    );
  }

  Animation<double>? createBlurFilterAnimation() {
    if (flushbar.routeBlur == null) return null;

    return Tween(begin: 0.0, end: flushbar.routeBlur).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: const Interval(
          0.0,
          0.35,
          curve: Curves.easeInOutCirc,
        ),
      ),
    );
  }

  Animation<Color?>? createColorFilterAnimation() {
    if (flushbar.routeColor == null) return null;

    return ColorTween(begin: Colors.transparent, end: flushbar.routeColor).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: const Interval(
          0.0,
          0.35,
          curve: Curves.easeInOutCirc,
        ),
      ),
    );
  }

  //copy of `routes.dart`
  void _handleStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.completed:
        currentStatus = FlushbarStatus.SHOWING;
        if (_onStatusChanged != null) _onStatusChanged(currentStatus);
        if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = opaque;

        break;
      case AnimationStatus.forward:
        currentStatus = FlushbarStatus.IS_APPEARING;
        if (_onStatusChanged != null) _onStatusChanged(currentStatus);
        break;
      case AnimationStatus.reverse:
        currentStatus = FlushbarStatus.IS_HIDING;
        if (_onStatusChanged != null) _onStatusChanged(currentStatus);
        if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = false;
        break;
      case AnimationStatus.dismissed:
        assert(!overlayEntries.first.opaque);
        // We might still be the current route if a subclass is controlling the
        // the transition and hits the dismissed status. For example, the iOS
        // back gesture drives this animation to the dismissed status before
        // popping the navigator.
        currentStatus = FlushbarStatus.DISMISSED;
        if (_onStatusChanged != null) _onStatusChanged(currentStatus);

        if (!isCurrent) {
          navigator!.finalizeRoute(this);
          if (overlayEntries.isNotEmpty) {
            overlayEntries.clear();
          }
          assert(overlayEntries.isEmpty);
        }
        break;
    }
    changedInternalState();
  }

  @override
  void install() {
    assert(!_transitionCompleter.isCompleted, 'Cannot install a $runtimeType after disposing it.');
    _controller = createAnimationController();
    assert(_controller != null, '$runtimeType.createAnimationController() returned null.');
    _filterBlurAnimation = createBlurFilterAnimation();
    _filterColorAnimation = createColorFilterAnimation();
    _animation = createAnimation();
    _slideAnimation = createSlideAnimation();
    assert(_animation != null, '$runtimeType.createAnimation() returned null.');
    super.install();
  }

  @override
  TickerFuture didPush() {
    assert(_controller != null, '$runtimeType.didPush called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    _animation!.addStatusListener(_handleStatusChanged);
    _configureTimer();
    super.didPush();
    return _controller!.forward();
  }

  @override
  void didReplace(Route<dynamic>? oldRoute) {
    assert(_controller != null, '$runtimeType.didReplace called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');
    if (oldRoute is FlushbarRoute) {
      _controller!.value = oldRoute._controller!.value;
    }
    _animation!.addStatusListener(_handleStatusChanged);
    super.didReplace(oldRoute);
  }

  @override
  bool didPop(T? result) {
    assert(_controller != null, '$runtimeType.didPop called before calling install() or after calling dispose().');
    assert(!_transitionCompleter.isCompleted, 'Cannot reuse a $runtimeType after disposing it.');

    _result = result;
    _cancelTimer();

    if (_wasDismissedBySwipe) {
      Timer(const Duration(milliseconds: 200), () {
        _controller!.reset();
      });

      _wasDismissedBySwipe = false;
    } else {
      _controller!.reverse();
    }

    return super.didPop(result);
  }

  void _configureTimer() {
    if (flushbar.duration != null) {
      if (_timer != null && _timer!.isActive) {
        _timer!.cancel();
      }
      _timer = Timer(flushbar.duration!, () {
        if (isCurrent) {
          navigator!.pop();
        } else if (isActive) {
          navigator!.removeRoute(this);
        }
      });
    } else {
      if (_timer != null) {
        _timer!.cancel();
      }
    }
  }

  void _cancelTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
  }

  /// Whether this route can perform a transition to the given route.
  ///
  /// Subclasses can override this method to restrict the set of routes they
  /// need to coordinate transitions with.
  bool canTransitionTo(FlushbarRoute<dynamic> nextRoute) => true;

  /// Whether this route can perform a transition from the given route.
  ///
  /// Subclasses can override this method to restrict the set of routes they
  /// need to coordinate transitions with.
  bool canTransitionFrom(FlushbarRoute<dynamic> previousRoute) => true;

  @override
  void dispose() {
    assert(!_transitionCompleter.isCompleted, 'Cannot dispose a $runtimeType twice.');
    _controller?.dispose();
    _transitionCompleter.complete(_result);
    _timer?.cancel();
    super.dispose();
  }

  /// A short description of this route useful for debugging.
  String get debugLabel => '$runtimeType';

  @override
  String toString() => '$runtimeType(animation: $_controller)';
}

FlushbarRoute showFlushbar<T>({required BuildContext context, required Flushbar flushbar}) {
  return FlushbarRoute<T>(
    flushbar: flushbar,
    settings: const RouteSettings(name: FLUSHBAR_ROUTE_NAME),
  );
}
