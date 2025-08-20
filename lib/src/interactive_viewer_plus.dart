import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/physics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'helper_methods.dart';

enum GestureType { pan, scale, rotate }

typedef InteractiveViewerWidgetBuilder =
    Widget Function(BuildContext context, Quad viewport);

@immutable
class InteractiveViewerPlus extends StatefulWidget {
  final bool panEnabled;

  final bool scaleEnabled;

  final bool rotateEnabled;

  final double maxScale;

  final double minScale;

  final double scaleFactor;

  final PanAxis panAxis;

  final bool constrained;

  final EdgeInsets boundaryMargin;

  final Clip clipBehavior;

  final Alignment? alignment;

  final Widget? child;

  final InteractiveViewerWidgetBuilder? builder;

  final InteractiveViewerPlusController? controller;

  final bool trackpadScrollCausesScale;

  final double interactionEndFrictionCoefficient;

  final GestureScaleEndCallback? onInteractionEnd;

  final GestureScaleStartCallback? onInteractionStart;

  final GestureScaleUpdateCallback? onInteractionUpdate;

  static const _kDrag = 0.0000135;

  InteractiveViewerPlus({
    required Widget this.child,
    super.key,
    this.alignment,
    this.controller,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.maxScale = 2.5,
    this.minScale = 0.8,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.rotateEnabled = true,
    this.constrained = true,
    this.panAxis = PanAxis.free,
    this.clipBehavior = Clip.hardEdge,
    this.boundaryMargin = EdgeInsets.zero,
    this.trackpadScrollCausesScale = false,
    this.interactionEndFrictionCoefficient = _kDrag,
    this.scaleFactor = kDefaultMouseScrollToScaleFactor,
  }) : assert(minScale > 0),
       assert(interactionEndFrictionCoefficient > 0),
       assert(minScale.isFinite),
       assert(maxScale > 0),
       assert(!maxScale.isNaN),
       assert(maxScale >= minScale),
       assert(
         (boundaryMargin.horizontal.isInfinite &&
                 boundaryMargin.vertical.isInfinite) ||
             (boundaryMargin.top.isFinite &&
                 boundaryMargin.right.isFinite &&
                 boundaryMargin.bottom.isFinite &&
                 boundaryMargin.left.isFinite),
       ),
       builder = null;

  InteractiveViewerPlus.builder({
    required InteractiveViewerWidgetBuilder this.builder,
    super.key,
    this.alignment,
    this.controller,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.maxScale = 2.5,
    this.minScale = 0.8,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.rotateEnabled = true,
    this.panAxis = PanAxis.free,
    this.clipBehavior = Clip.hardEdge,
    this.boundaryMargin = EdgeInsets.zero,
    this.trackpadScrollCausesScale = false,
    this.interactionEndFrictionCoefficient = _kDrag,
    this.scaleFactor = kDefaultMouseScrollToScaleFactor,
  }) : assert(minScale > 0),
       assert(interactionEndFrictionCoefficient > 0),
       assert(minScale.isFinite),
       assert(maxScale > 0),
       assert(!maxScale.isNaN),
       assert(maxScale >= minScale),
       assert(
         (boundaryMargin.horizontal.isInfinite &&
                 boundaryMargin.vertical.isInfinite) ||
             (boundaryMargin.top.isFinite &&
                 boundaryMargin.right.isFinite &&
                 boundaryMargin.bottom.isFinite &&
                 boundaryMargin.left.isFinite),
       ),
       child = null,
       constrained = false;

  @override
  State<InteractiveViewerPlus> createState() => _InteractiveViewerPlusState();
}

class _InteractiveViewerPlusState extends State<InteractiveViewerPlus>
    with TickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey();
  final GlobalKey _parentKey = GlobalKey();

  Animation<Offset>? _animation;
  Animation<double>? _scaleAnimation;

  late Offset _scaleAnimationFocalPoint;

  late AnimationController _animationController;
  late AnimationController _scaleAnimationController;

  Axis? _currentAxis;
  Offset? _referenceFocalPoint;

  double? _scaleStart;
  double? _rotationStart;

  GestureType? _gestureType;

  late InteractiveViewerPlusController _controller =
      widget.controller ?? InteractiveViewerPlusController();

  Rect get _boundaryRect {
    assert(_childKey.currentContext != null);
    assert(!widget.boundaryMargin.left.isNaN);
    assert(!widget.boundaryMargin.right.isNaN);
    assert(!widget.boundaryMargin.top.isNaN);
    assert(!widget.boundaryMargin.bottom.isNaN);

    final childRenderBox =
        _childKey.currentContext!.findRenderObject()! as RenderBox;

    final childSize = childRenderBox.size;

    final boundaryRect = widget.boundaryMargin.inflateRect(
      Offset.zero & childSize,
    );

    assert(
      !boundaryRect.isEmpty,
      "InteractiveViewer's child must have nonzero dimensions.",
    );

    assert(
      boundaryRect.isFinite ||
          (boundaryRect.left.isInfinite &&
              boundaryRect.top.isInfinite &&
              boundaryRect.right.isInfinite &&
              boundaryRect.bottom.isInfinite),
      '''
      boundaryRect must either be infinite in all directions or finite in all 
      directions.
      ''',
    );
    return boundaryRect;
  }

  Rect get _viewport {
    assert(_parentKey.currentContext != null);
    final parentRenderBox =
        _parentKey.currentContext!.findRenderObject()! as RenderBox;
    return Offset.zero & parentRenderBox.size;
  }

  bool _gestureIsSupported(GestureType? gestureType) => switch (gestureType) {
    GestureType.rotate => widget.rotateEnabled,
    GestureType.scale => widget.scaleEnabled,
    GestureType.pan || null => widget.panEnabled,
  };

  GestureType _getGestureType(ScaleUpdateDetails details) {
    final scale = !widget.scaleEnabled ? 1.0 : details.scale;
    final rotation = !widget.rotateEnabled ? 0.0 : details.rotation;
    if ((scale - 1).abs() > rotation.abs()) {
      return GestureType.scale;
    } else if (rotation != 0.0) {
      return GestureType.rotate;
    } else {
      return GestureType.pan;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    widget.onInteractionStart?.call(details);

    if (_animationController.isAnimating) {
      _animationController
        ..stop()
        ..reset();
      _animation?.removeListener(_handleInertiaAnimation);
      _animation = null;
    }

    if (_scaleAnimationController.isAnimating) {
      _scaleAnimationController
        ..stop()
        ..reset();
      _scaleAnimation?.removeListener(_handleScaleAnimation);
      _scaleAnimation = null;
    }

    _gestureType = null;
    _currentAxis = null;
    _scaleStart = _controller.value.getMaxScaleOnAxis();
    _referenceFocalPoint = _controller.toScene(details.localFocalPoint);
    _rotationStart = _controller.currentRotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _scaleAnimationFocalPoint = details.localFocalPoint;

    final scale = _controller.value.getMaxScaleOnAxis();

    final focalPointScene = _controller.toScene(details.localFocalPoint);

    if (_gestureType == GestureType.pan) {
      _gestureType = _getGestureType(details);
    } else {
      _gestureType ??= _getGestureType(details);
    }

    if (!_gestureIsSupported(_gestureType)) {
      widget.onInteractionUpdate?.call(details);
      return;
    }

    switch (_gestureType!) {
      case GestureType.scale:
        assert(_scaleStart != null);

        final desiredScale = _scaleStart! * details.scale;
        final scaleChange = desiredScale / scale;
        _controller.value = _controller.matrixScale(
          _controller.value,
          scaleChange,
        );

        final focalPointSceneScaled = _controller.toScene(
          details.localFocalPoint,
        );

        _controller.value = _controller.matrixTranslate(
          _controller.value,
          focalPointSceneScaled - _referenceFocalPoint!,
        );

        final focalPointSceneCheck = _controller.toScene(
          details.localFocalPoint,
        );

        if (round(_referenceFocalPoint!) != round(focalPointSceneCheck)) {
          _referenceFocalPoint = focalPointSceneCheck;
        }

      case GestureType.rotate:
        if (details.rotation == 0.0) {
          widget.onInteractionUpdate?.call(details);
          return;
        }

        final desiredRotation = _rotationStart! + details.rotation;
        _controller.value = _controller.matrixRotate(
          _controller.value,
          _controller.currentRotation - desiredRotation,
          details.localFocalPoint,
        );

        _controller.currentRotation = desiredRotation;

      case GestureType.pan:
        assert(_referenceFocalPoint != null);

        if (details.scale != 1.0) {
          widget.onInteractionUpdate?.call(details);
          return;
        }

        _currentAxis ??= getPanAxis(_referenceFocalPoint!, focalPointScene);

        final translationChange = focalPointScene - _referenceFocalPoint!;
        _controller.value = _controller.matrixTranslate(
          _controller.value,
          translationChange,
        );

        _referenceFocalPoint = _controller.toScene(details.localFocalPoint);
    }
    widget.onInteractionUpdate?.call(details);
  }

  Future<void> _onScaleEnd(ScaleEndDetails details) async {
    widget.onInteractionEnd?.call(details);

    _scaleStart = null;
    _rotationStart = null;
    _referenceFocalPoint = null;

    _animation?.removeListener(_handleInertiaAnimation);
    _scaleAnimation?.removeListener(_handleScaleAnimation);

    _animationController.reset();
    _scaleAnimationController.reset();

    if (!_gestureIsSupported(_gestureType)) {
      _currentAxis = null;
      return;
    }

    switch (_gestureType) {
      case GestureType.pan:
        if (details.velocity.pixelsPerSecond.distance < kMinFlingVelocity) {
          _currentAxis = null;
          return;
        }
        final translationVector = _controller.value.getTranslation();
        final translation = Offset(translationVector.x, translationVector.y);
        final frictionSimulationX = FrictionSimulation(
          widget.interactionEndFrictionCoefficient,
          translation.dx,
          details.velocity.pixelsPerSecond.dx,
        );
        final frictionSimulationY = FrictionSimulation(
          widget.interactionEndFrictionCoefficient,
          translation.dy,
          details.velocity.pixelsPerSecond.dy,
        );
        final tFinal = getFinalTime(
          details.velocity.pixelsPerSecond.distance,
          widget.interactionEndFrictionCoefficient,
        );
        _animation =
            Tween<Offset>(
              begin: translation,
              end: Offset(
                frictionSimulationX.finalX,
                frictionSimulationY.finalX,
              ),
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.decelerate,
              ),
            );
        _animationController.duration = Duration(
          milliseconds: (tFinal * 1000).round(),
        );
        _animation!.addListener(_handleInertiaAnimation);
        await _animationController.forward();
      case GestureType.scale:
        if (details.scaleVelocity.abs() < 0.1) {
          _currentAxis = null;
          return;
        }
        final scale = _controller.value.getMaxScaleOnAxis();
        final frictionSimulation = FrictionSimulation(
          widget.interactionEndFrictionCoefficient * widget.scaleFactor,
          scale,
          details.scaleVelocity / 10,
        );
        final tFinal = getFinalTime(
          details.scaleVelocity.abs(),
          widget.interactionEndFrictionCoefficient,
          effectivelyMotionless: 0.1,
        );
        _scaleAnimation =
            Tween<double>(
              begin: scale,
              end: frictionSimulation.x(tFinal),
            ).animate(
              CurvedAnimation(
                parent: _scaleAnimationController,
                curve: Curves.decelerate,
              ),
            );
        _scaleAnimationController.duration = Duration(
          milliseconds: (tFinal * 1000).round(),
        );
        _scaleAnimation!.addListener(_handleScaleAnimation);
        await _scaleAnimationController.forward();
      case GestureType.rotate || null:
        break;
    }
  }

  void _receivedPointerSignal(PointerSignalEvent event) {
    final local = event.localPosition;
    final global = event.position;
    final double scaleChange;
    if (event is PointerScrollEvent) {
      if (event.kind == PointerDeviceKind.trackpad &&
          !widget.trackpadScrollCausesScale) {
        widget.onInteractionStart?.call(
          ScaleStartDetails(focalPoint: global, localFocalPoint: local),
        );

        final localDelta = PointerEvent.transformDeltaViaPositions(
          untransformedEndPosition: global + event.scrollDelta,
          untransformedDelta: event.scrollDelta,
          transform: event.transform,
        );

        if (!_gestureIsSupported(GestureType.pan)) {
          widget.onInteractionUpdate?.call(
            ScaleUpdateDetails(
              focalPoint: global - event.scrollDelta,
              localFocalPoint: local - event.scrollDelta,
              focalPointDelta: -localDelta,
            ),
          );
          widget.onInteractionEnd?.call(ScaleEndDetails());
          return;
        }

        final focalPointScene = _controller.toScene(local);
        final newFocalPointScene = _controller.toScene(local - localDelta);

        _controller.value = _controller.matrixTranslate(
          _controller.value,
          newFocalPointScene - focalPointScene,
        );

        widget.onInteractionUpdate?.call(
          ScaleUpdateDetails(
            focalPoint: global - event.scrollDelta,
            localFocalPoint: local - localDelta,
            focalPointDelta: -localDelta,
          ),
        );
        widget.onInteractionEnd?.call(ScaleEndDetails());
        return;
      }

      if (event.scrollDelta.dy == 0.0) {
        return;
      }
      scaleChange = math.exp(-event.scrollDelta.dy / widget.scaleFactor);
    } else if (event is PointerScaleEvent) {
      scaleChange = event.scale;
    } else {
      return;
    }
    widget.onInteractionStart?.call(
      ScaleStartDetails(focalPoint: global, localFocalPoint: local),
    );

    if (!_gestureIsSupported(GestureType.scale)) {
      widget.onInteractionUpdate?.call(
        ScaleUpdateDetails(
          focalPoint: global,
          localFocalPoint: local,
          scale: scaleChange,
        ),
      );
      widget.onInteractionEnd?.call(ScaleEndDetails());
      return;
    }

    final focalPointScene = _controller.toScene(local);
    _controller.value = _controller.matrixScale(_controller.value, scaleChange);

    final focalPointSceneScaled = _controller.toScene(local);
    _controller.value = _controller.matrixTranslate(
      _controller.value,
      focalPointSceneScaled - focalPointScene,
    );

    widget.onInteractionUpdate?.call(
      ScaleUpdateDetails(
        focalPoint: global,
        localFocalPoint: local,
        scale: scaleChange,
      ),
    );

    widget.onInteractionEnd?.call(ScaleEndDetails());
  }

  void _handleInertiaAnimation() {
    if (!_animationController.isAnimating) {
      _currentAxis = null;
      _animation?.removeListener(_handleInertiaAnimation);
      _animation = null;
      _animationController.reset();
      return;
    }

    final translationVector = _controller.value.getTranslation();

    final translation = Offset(translationVector.x, translationVector.y);

    _controller.value = _controller.matrixTranslate(
      _controller.value,
      _controller.toScene(_animation!.value) - _controller.toScene(translation),
    );
  }

  void _handleScaleAnimation() {
    if (!_scaleAnimationController.isAnimating) {
      _currentAxis = null;
      _scaleAnimation?.removeListener(_handleScaleAnimation);
      _scaleAnimation = null;
      _scaleAnimationController.reset();
      return;
    }

    final desiredScale = _scaleAnimation!.value;

    final scaleChange = desiredScale / _controller.value.getMaxScaleOnAxis();

    final referenceFocalPoint = _controller.toScene(_scaleAnimationFocalPoint);

    _controller.value = _controller.matrixScale(_controller.value, scaleChange);

    final focalPointSceneScaled = _controller.toScene(
      _scaleAnimationFocalPoint,
    );

    _controller.value = _controller.matrixTranslate(
      _controller.value,
      focalPointSceneScaled - referenceFocalPoint,
    );
  }

  void _handleTransformation() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _scaleAnimationController = AnimationController(vsync: this);

    _controller.addListener(_handleTransformation);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.setValues(
        viewport: _viewport,
        panAxis: widget.panAxis,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        currentAxis: _currentAxis,
        boundaryRect: _boundaryRect,
      );
    });
  }

  @override
  void didUpdateWidget(InteractiveViewerPlus oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newController = widget.controller;
    if (newController == oldWidget.controller) {
      return;
    }
    _controller.removeListener(_handleTransformation);
    if (oldWidget.controller == null) {
      _controller.dispose();
    }
    _controller = newController ?? InteractiveViewerPlusController();
    _controller
      ..addListener(_handleTransformation)
      ..setValues(
        viewport: _viewport,
        panAxis: widget.panAxis,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        currentAxis: _currentAxis,
        boundaryRect: _boundaryRect,
      );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleAnimationController.dispose();
    _controller.removeListener(_handleTransformation);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.child != null) {
      child = _InteractiveViewerBuilt(
        childKey: _childKey,
        clipBehavior: widget.clipBehavior,
        constrained: widget.constrained,
        matrix: _controller.value,
        alignment: widget.alignment,
        child: widget.child!,
      );
    } else {
      assert(widget.builder != null);
      assert(!widget.constrained);
      child = LayoutBuilder(
        builder: (context, constraints) {
          final matrix = _controller.value;
          return _InteractiveViewerBuilt(
            childKey: _childKey,
            clipBehavior: widget.clipBehavior,
            constrained: widget.constrained,
            alignment: widget.alignment,
            matrix: matrix,
            child: widget.builder!(
              context,
              transformViewport(matrix, Offset.zero & constraints.biggest),
            ),
          );
        },
      );
    }

    return Listener(
      key: _parentKey,
      onPointerSignal: _receivedPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleEnd: _onScaleEnd,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        trackpadScrollCausesScale: widget.trackpadScrollCausesScale,
        trackpadScrollToScaleFactor: Offset(0, -1 / widget.scaleFactor),
        child: child,
      ),
    );
  }
}

class _InteractiveViewerBuilt extends StatelessWidget {
  final Widget child;

  final GlobalKey childKey;

  final Clip clipBehavior;

  final bool constrained;

  final Matrix4 matrix;

  final Alignment? alignment;

  const _InteractiveViewerBuilt({
    required this.child,
    required this.childKey,
    required this.clipBehavior,
    required this.constrained,
    required this.matrix,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = Transform(
      transform: matrix,
      alignment: alignment,
      child: KeyedSubtree(key: childKey, child: this.child),
    );

    if (!constrained) {
      child = OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: child,
      );
    }

    return ClipRect(clipBehavior: clipBehavior, child: child);
  }
}
