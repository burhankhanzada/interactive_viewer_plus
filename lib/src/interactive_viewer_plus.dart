import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'helper_methods.dart';

// A classification of relevant user gestures. Each contiguous user gesture is
// represented by exactly one _GestureType.
enum GestureType { pan, scale, rotate }

/// [InteractiveViewerPlus] is a drop in replacement and enhanced version of
/// Flutter's [InteractiveViewer] that adds support for pan, zoom, and rotation,
/// flip and improved programmatic control through
/// [InteractiveViewerPlusController].
///
/// ## Programmatic Control
///
/// Use [InteractiveViewerPlusController] for programmatic manipulation:
///
/// ```dart
/// final controller = InteractiveViewerPlusController();
///
/// InteractiveViewerPlus(
///   controller: controller,
///   child: MyWidget(),
/// )
///
/// controller.zoom(1.5);  // Zoom in by 50%
/// controller.rotate(math.pi / 4);  // Rotate 45 degrees
/// controller.flip(flipX: true);  // Flip horizontally
/// ```
/// A widget that enables pan and zoom interactions with its child.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=zrn7V3bMJvg}
///
/// The user can transform the child by dragging to pan or pinching to zoom.
///
/// By default, InteractiveViewer clips its child using [Clip.hardEdge].
/// To prevent this behavior, consider setting [clipBehavior] to [Clip.none].
/// When [clipBehavior] is [Clip.none], InteractiveViewer may draw outside of
/// its original area of the screen, such as when a child is zoomed in and
/// increases in size. However, it will not receive gestures outside of its
/// original area.
/// To prevent dead areas where InteractiveViewer does not receive gestures,
/// don't set [clipBehavior] or be sure that the InteractiveViewer widget is the
/// size of the area that should be interactive.
///
/// See also:
///   * The [Flutter Gallery's transformations demo](https://github.com/flutter/gallery/blob/main/lib/demos/reference/transformations_demo.dart),
///     which includes the use of InteractiveViewer.
///   * The [flutter-go demo](https://github.com/justinmc/flutter-go), which includes robust positioning of an InteractiveViewer child
///     that works for all screen sizes and child sizes.
///   * The [Lazy Flutter Performance Session](https://www.youtube.com/watch?v=qax_nOpgz7E), which includes the use of an InteractiveViewer to
///     performantly view subsets of a large set of widgets using the builder
///     constructor.
///
/// {@tool dartpad}
/// This example shows a simple Container that can be panned and zoomed.
///
/// ** See code in examples/api/lib/widgets/interactive_viewer/interactive_viewer.0.dart **
/// {@end-tool}
@immutable
class InteractiveViewerPlus extends StatefulWidget {
  /// Whether pan gestures are enabled.
  ///
  /// Defaults to true.
  ///
  /// When false, the user will not be able to pan the content.
  ///
  /// See also:
  ///
  ///   * [scaleEnabled], which is similar but for scaling.
  ///   * [rotateEnabled], which is similar but for rotation.
  final bool panEnabled;

  /// Whether zoom gestures are enabled.
  ///
  /// Defaults to true.
  ///
  /// When false, the user will not be able to zoom the content.
  ///
  /// See also:
  ///
  ///   * [panEnabled], which is similar but for panning.
  ///   * [rotateEnabled], which is similar but for rotation.
  final bool scaleEnabled;

  /// Whether rotation gestures are enabled.
  ///
  /// Defaults to true.
  ///
  /// When false, the user will not be able to rotate the content.
  ///
  /// See also:
  ///
  ///   * [panEnabled], which is similar but for panning.
  ///   * [scaleEnabled], which is similar but for scaling.
  final bool rotateEnabled;

  /// The minimum allowed scale.
  ///
  /// The scale will be clamped between this and [maxScale] inclusively.
  ///
  /// Scale is also affected by [boundaryMargin]. If the scale would result in
  /// viewing beyond the boundary, then it will not be allowed. By default,
  /// boundaryMargin is EdgeInsets.zero, so scaling below 1.0 will not be
  /// allowed in most cases without first increasing the boundaryMargin.
  ///
  /// Defaults to 0.8.
  ///
  /// Must be a finite number greater than zero and less than [maxScale].
  final double minScale;

  /// The maximum allowed scale.
  ///
  /// The scale will be clamped between this and [minScale] inclusively.
  ///
  /// Defaults to 2.5.
  ///
  /// Must be greater than zero and greater than [minScale].
  final double maxScale;

  /// Determines the amount of scale to be performed per pointer scroll.
  ///
  /// Defaults to [kDefaultMouseScrollToScaleFactor].
  ///
  /// Increasing this value above the default causes scaling to feel slower,
  /// while decreasing it causes scaling to feel faster.
  ///
  /// The amount of scale is calculated as the exponential function of the
  /// [PointerScrollEvent.scrollDelta] to [scaleFactor] ratio. In the Flutter
  /// engine, the mousewheel [PointerScrollEvent.scrollDelta] is hardcoded to 20
  /// per scroll, while a trackpad scroll can be any amount.
  ///
  /// Affects only pointer device scrolling, not pinch to zoom.
  final double scaleFactor;

  /// When set to [PanAxis.aligned], panning is only allowed in the horizontal
  /// axis or the vertical axis, diagonal panning is not allowed.
  ///
  /// When set to [PanAxis.vertical] or [PanAxis.horizontal] panning is only
  /// allowed in the specified axis. For example, if set to [PanAxis.vertical],
  /// panning will only be allowed in the vertical axis. And if set to
  /// [PanAxis.horizontal], panning will only be allowed in the horizontal axis.
  ///
  /// When set to [PanAxis.free] panning is allowed in all directions.
  ///
  /// Defaults to [PanAxis.free].
  final PanAxis panAxis;

  /// Whether the child should be constrained to the viewport size.
  ///
  /// Whether the normal size constraints at this point in the widget tree are
  /// applied to the child.
  ///
  /// If set to false, then the child will be given infinite constraints. This
  /// is often useful when a child should be bigger than the InteractiveViewer.
  ///
  /// When true, the child is clipped to fit within the viewport.
  /// When false (only available with builder constructor), the child can extend
  /// beyond the viewport.
  ///
  /// For example, for a child which is bigger than the viewport but can be
  /// panned to reveal parts that were initially offscreen, [constrained] must
  /// be set to false to allow it to size itself properly. If [constrained] is
  /// true and the child can only size itself to the viewport, then areas
  /// initially outside of the viewport will not be able to receive user
  /// interaction events. If experiencing regions of the child that are not
  /// receptive to user gestures, make sure [constrained] is false and the child
  /// is sized properly.
  ///
  /// Defaults to true.
  ///
  /// {@tool dartpad}
  /// This example shows how to create a pannable table. Because the table is
  /// larger than the entire screen, setting [constrained] to false is necessary
  /// to allow it to be drawn to its full size. The parts of the table that
  /// exceed the screen size can then be panned into view.
  ///
  /// ** See code in examples/api/lib/widgets/interactive_viewer/interactive_viewer.constrained.0.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///   * [ListView.builder], which follows a similar pattern.
  final bool constrained;

  /// A margin for the visible boundaries of the child.
  ///
  /// Any transformation that results in the viewport being able to view outside
  /// of the boundaries will be stopped at the boundary. The boundaries do not
  /// rotate with the rest of the scene, so they are always aligned with the
  /// viewport.
  ///
  /// To produce no boundaries at all, pass infinite [EdgeInsets], such as
  /// `EdgeInsets.all(double.infinity)`.
  ///
  /// No edge can be NaN.
  ///
  /// Defaults to [EdgeInsets.zero], which results in boundaries that are the
  /// exact same size and position as the [child].
  final EdgeInsets boundaryMargin;

  /// If set to [Clip.none], the child may extend beyond the size of the
  /// [InteractiveViewerPlus], but it will not receive gestures in these areas.
  /// Be sure that the InteractiveViewer is the desired size when using
  /// [Clip.none].
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// The alignment of the child's origin, relative to the size of the box.
  final Alignment? alignment;

  /// The child [Widget] that is transformed by [InteractiveViewerPlus].
  ///
  /// If the [InteractiveViewer.builder] constructor is used, then this will be
  /// null, otherwise it is required.
  final Widget? child;

  /// Builds the child of this widget.
  ///
  /// Passed with the [InteractiveViewerPlus.builder] constructor. Otherwise,
  /// the [child] parameter must be passed directly, and this is null.
  ///
  /// {@tool dartpad}
  /// This example shows how to use builder to create a [Table] whose cell
  /// contents are only built when they are visible. Built and remove cells are
  /// logged in the console for illustration.
  ///
  /// ** See code in examples/api/lib/widgets/interactive_viewer/interactive_viewer.builder.0.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///   * [ListView.builder], which follows a similar pattern.
  final InteractiveViewerWidgetBuilder? builder;

  /// A [InteractiveViewerPlusController] for the transformation performed on
  /// the child.
  ///
  /// Whenever the child is transformed, the [Matrix4] value is updated and all
  /// listeners are notified. If the value is set, InteractiveViewer will update
  /// to respect the new value.
  ///
  /// {@tool dartpad}
  /// This example shows how transformationController can be used to animate the
  /// transformation back to its starting position.
  ///
  /// ** See code in examples/api/lib/widgets/interactive_viewer/interactive_viewer.transformation_controller.0.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [ValueNotifier], the parent class of TransformationController.
  ///  * [TextEditingController] for an example of another similar pattern.
  final InteractiveViewerPlusController? controller;

  /// Whether trackpad scroll events should cause scaling instead of panning.
  ///
  /// When false (default), trackpad scroll will pan the content.
  /// When true, trackpad scroll will zoom the content.
  /// {@macro flutter.gestures.scale.trackpadScrollCausesScale}
  final bool trackpadScrollCausesScale;

  /// The friction coefficient for momentum animations after user interaction
  /// ends.
  ///
  /// Defaults to 0.0000135.
  ///
  /// Lower values create longer momentum animations.
  /// Must be a finite number greater than zero.
  final double interactionEndFrictionCoefficient;

  /// Called when the user ends a pan or scale gesture on the widget.
  ///
  /// At the time this is called, the [TransformationController] will have
  /// already been updated to reflect the change caused by the interaction,
  /// though a pan may cause an inertia animation after this is called as well.
  ///
  /// {@template flutter.widgets.InteractiveViewer.onInteractionEnd}
  /// Will be called even if the interaction is disabled with [panEnabled] or
  /// [scaleEnabled] for both touch gestures and mouse interactions.
  ///
  /// A [GestureDetector] wrapping the InteractiveViewer will not respond to
  /// [GestureDetector.onScaleStart], [GestureDetector.onScaleUpdate], and
  /// [GestureDetector.onScaleEnd]. Use [onInteractionStart],
  /// [onInteractionUpdate], and [onInteractionEnd] to respond to those
  /// gestures.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [onInteractionStart], which handles the start of the same interaction.
  ///  * [onInteractionUpdate], which handles an update to the same interaction.
  final GestureScaleEndCallback? onInteractionEnd;

  /// Called when the user begins a pan or scale gesture on the widget.
  ///
  /// At the time this is called, the [TransformationController] will not have
  /// changed due to this interaction.
  ///
  /// {@macro flutter.widgets.InteractiveViewer.onInteractionEnd}
  ///
  /// The coordinates provided in the details' `focalPoint` and
  /// `localFocalPoint` are normal Flutter event coordinates, not
  /// InteractiveViewer scene coordinates. See
  /// [TransformationController.toScene] for how to convert these coordinates to
  /// scene coordinates relative to the child.
  ///
  /// See also:
  ///
  ///  * [onInteractionUpdate], which handles an update to the same interaction.
  ///  * [onInteractionEnd], which handles the end of the same interaction.
  final GestureScaleStartCallback? onInteractionStart;

  /// Called when the user updates a pan or scale gesture on the widget.
  ///
  /// At the time this is called, the [TransformationController] will have
  /// already been updated to reflect the change caused by the interaction, if
  /// the interaction caused the matrix to change.
  ///
  /// {@macro flutter.widgets.InteractiveViewer.onInteractionEnd}
  ///
  /// The coordinates provided in the details' `focalPoint` and
  /// `localFocalPoint` are normal Flutter event coordinates, not
  /// InteractiveViewer scene coordinates. See
  /// [TransformationController.toScene] for how to convert these coordinates to
  /// scene coordinates relative to the child.
  ///
  /// See also:
  ///
  ///  * [onInteractionStart], which handles the start of the same interaction.
  ///  * [onInteractionEnd], which handles the end of the same interaction.
  final GestureScaleUpdateCallback? onInteractionUpdate;

  // Used as the coefficient of friction in the inertial translation animation.
  // This value was eyeballed to give a feel similar to Google Photos.
  static const _kDrag = 0.0000135;

  /// Creates an [InteractiveViewerPlus].
  InteractiveViewerPlus({
    required Widget this.child,
    super.key,
    this.alignment,
    this.controller,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    // These default scale values were eyeballed as reasonable limits for common
    // use cases.
    this.minScale = 0.8,
    this.maxScale = 2.5,
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
       // boundaryMargin must be either fully infinite or fully finite, but not
       // a mix of both.
       assert(
         (boundaryMargin.horizontal.isInfinite &&
                 boundaryMargin.vertical.isInfinite) ||
             (boundaryMargin.top.isFinite &&
                 boundaryMargin.right.isFinite &&
                 boundaryMargin.bottom.isFinite &&
                 boundaryMargin.left.isFinite),
       ),
       builder = null;

  /// Creates an [InteractiveViewerPlus] for a child that is created on demand.
  ///
  /// Can be used to render a child that changes in response to the current
  /// transformation.
  ///
  /// See the [builder] attribute docs for an example of using it to optimize a
  /// large child.
  InteractiveViewerPlus.builder({
    required InteractiveViewerWidgetBuilder this.builder,
    super.key,
    this.alignment,
    this.controller,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    // These default scale values were eyeballed as reasonable limits for common
    // use cases.
    this.minScale = 0.8,
    this.maxScale = 2.5,
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
       // boundaryMargin must be either fully infinite or fully finite, but not
       // a mix of both.
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
  /// Global key for the child widget to access its render object and size.
  ///
  /// Used to calculate boundary constraints and the child's actual dimensions
  /// for boundary checking and transformation calculations.
  final GlobalKey _childKey = GlobalKey();

  /// Global key for the parent widget to access its render object and size.
  ///
  /// Used to determine the viewport size for coordinate transformations
  /// and boundary calculations.
  final GlobalKey _parentKey = GlobalKey();

  /// Animation for momentum-based panning after gesture ends.
  ///
  /// This animation provides smooth deceleration when the user releases
  /// a pan gesture with velocity, creating natural inertia behavior.
  Animation<Offset>? _animation;

  /// Animation for momentum-based scaling after gesture ends.
  ///
  /// This animation provides smooth deceleration when the user releases
  /// a scale gesture with velocity, creating natural zoom inertia.
  Animation<double>? _scaleAnimation;

  /// The focal point around which scale animations are applied.
  ///
  /// This point remains stable during scale animations, ensuring that
  /// the content under this point stays in place while zooming.
  late Offset _scaleAnimationFocalPoint;

  /// Animation controller for pan momentum animations.
  ///
  /// Controls the timing and curve of inertial panning motion after
  /// the user releases a pan gesture with sufficient velocity.
  late AnimationController _animationController;

  /// Animation controller for scale momentum animations.
  ///
  /// Controls the timing and curve of inertial scaling motion after
  /// the user releases a scale gesture with sufficient velocity.
  late AnimationController _scaleAnimationController;

  /// The currently detected primary axis for axis-aligned panning.
  ///
  /// When [PanAxis.aligned] is used, this stores whether the user's
  /// initial movement was primarily horizontal or vertical, constraining
  /// subsequent movement to that axis.
  Axis? _currentAxis;

  /// Reference point in scene coordinates at the start of a gesture.
  ///
  /// Used to calculate relative movement during pan gestures by comparing
  /// the current gesture position to this reference point.
  Offset? _referenceFocalPoint;

  /// The scale factor recorded at the start of a scale gesture.
  ///
  /// Used to calculate the total scale change during multi-touch
  /// pinch-to-zoom gestures by comparing to the current gesture scale.
  double? _scaleStart;

  /// The rotation angle recorded at the start of a rotation gesture.
  ///
  /// Used to calculate the total rotation change during multi-touch
  /// rotation gestures by comparing to the current gesture rotation.
  double? _rotationStart;

  /// The currently active gesture type being processed.
  ///
  /// Determined by analyzing the gesture details to identify whether
  /// the user is primarily panning, scaling, or rotating. This ensures
  /// only one gesture type is active at a time for consistent behavior.
  GestureType? _gestureType;

  /// The controller managing transformation state and operations.
  ///
  /// Either provided by the widget or created internally. Handles all
  /// transformation matrix operations and boundary constraint enforcement.
  late InteractiveViewerPlusController _controller =
      widget.controller ?? InteractiveViewerPlusController();

  /// Computes the boundary rectangle that constrains transformations.
  ///
  /// This getter calculates the effective boundary based on the child's actual
  /// size inflated by `boundaryMargin`. The boundary is used to prevent
  /// the content from being moved outside of allowable limits during pan and
  /// zoom operations.
  ///
  /// Returns a [Rect] representing the boundary constraints, which can be
  /// either finite (normal boundaries) or infinite in all directions
  /// (no constraints).
  ///
  /// Throws an assertion error if the child has zero dimensions or if the
  /// boundary margins are inconsistent (mix of finite and infinite values).
  Rect get _boundaryRect {
    // The BuildContext of the child widget, used to access its RenderBox
    final context = _childKey.currentContext;

    assert(context != null);

    // The configured boundary margins that define transformation constraints
    final margin = widget.boundaryMargin;

    assert(!margin.left.isNaN);
    assert(!margin.right.isNaN);
    assert(!margin.top.isNaN);
    assert(!margin.bottom.isNaN);

    // The child widget's RenderBox, providing access to its physical dimensions
    final childRenderBox = context!.findRenderObject()! as RenderBox;

    // The actual pixel size of the child widget after layout
    final childSize = childRenderBox.size;

    // The boundary rectangle created by inflating the child's size by the
    // margins
    final boundaryRect = margin.inflateRect(Offset.zero & childSize);

    assert(
      !boundaryRect.isEmpty,
      "InteractiveViewer's child must have nonzero dimensions.",
    );

    // Individual boundary coordinates extracted for validation
    final left = boundaryRect.left;
    final top = boundaryRect.top;
    final right = boundaryRect.right;
    final bottom = boundaryRect.bottom;

    assert(
      boundaryRect.isFinite ||
          (left.isInfinite &&
              top.isInfinite &&
              right.isInfinite &&
              bottom.isInfinite),
      '''
      boundaryRect must either be infinite in all directions or finite in all 
      directions.
      ''',
    );

    return boundaryRect;
  }

  /// Gets the viewport rectangle representing the visible area.
  ///
  /// This getter computes the current viewport size by accessing the parent
  /// widget's render box dimensions. The viewport represents the area that
  /// the user can see, starting from the origin (0,0) and extending to the
  /// parent widget's size.
  ///
  /// Used for coordinate transformations, boundary calculations, and
  /// determining what portion of the scene is currently visible to the user.
  ///
  /// Returns a [Rect] with the viewport's dimensions.
  Rect get _viewport {
    assert(_parentKey.currentContext != null);

    // The parent widget's RenderBox, providing access to the viewport
    // dimensions
    final parentRenderBox =
        _parentKey.currentContext!.findRenderObject()! as RenderBox;

    return Offset.zero & parentRenderBox.size;
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

    // The controller from the updated widget configuration
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
    // The main child widget that will be wrapped with gesture detectors
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
          // Current transformation matrix for the builder pattern
          final matrix = _controller.value;
          return _InteractiveViewerBuilt(
            childKey: _childKey,
            clipBehavior: widget.clipBehavior,
            constrained: widget.constrained,
            alignment: widget.alignment,
            matrix: matrix,
            child: widget.builder!(
              context,
              _controller.transformViewport(
                matrix,
                Offset.zero & constraints.biggest,
              ),
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

  /// Listener for transformation changes that triggers widget rebuilds.
  ///
  /// This method is called whenever the controller's transformation matrix
  /// changes, ensuring that the widget rebuilds to reflect the new state.
  /// It simply calls [setState] to mark the widget as needing rebuild.
  ///
  /// This is essential for keeping the visual representation synchronized
  /// with the internal transformation state managed by the controller.
  void _handleTransformation() {
    setState(() {});
  }

  /// Checks whether a specific gesture type is enabled and supported.
  ///
  /// This method determines if the given [gestureType] should be processed
  /// based on the widget's configuration flags (`panEnabled`, `scaleEnabled`,
  /// `rotateEnabled`). Used to filter out disabled gestures during interaction.
  ///
  /// Returns `true` if the gesture type is supported, `false` otherwise.
  /// If [gestureType] is `null`, defaults to checking pan gesture support.
  bool _gestureIsSupported(GestureType? gestureType) => switch (gestureType) {
    GestureType.rotate => widget.rotateEnabled,
    GestureType.scale => widget.scaleEnabled,
    GestureType.pan || null => widget.panEnabled,
  };

  /// Determines the primary gesture type from scale update details.
  ///
  /// Decide which type of gesture this is by comparing the amount of scale
  /// and rotation in the gesture, if any. Scale starts at 1 and rotation
  /// starts at 0. Pan will have no scale and no rotation because it uses only
  /// one finger.
  ///
  /// Analyzes the [details] from a scale gesture to identify whether the user
  /// is primarily performing a scale (zoom), rotation, or pan gesture. This
  /// classification ensures that only one gesture type is active at a time,
  /// providing consistent and predictable behavior.
  ///
  /// The determination is based on comparing the magnitudes of scale change
  /// and rotation change, with scale taking precedence over rotation when
  /// both are present.
  ///
  /// Returns the detected [GestureType] for the current gesture.
  GestureType _getGestureType(ScaleUpdateDetails details) {
    // Scale factor from gesture, normalized to 1.0 if scaling is disabled
    final scale = !widget.scaleEnabled ? 1.0 : details.scale;

    // Rotation angle from gesture, normalized to 0.0 if rotation is disabled
    final rotation = !widget.rotateEnabled ? 0.0 : details.rotation;

    if ((scale - 1).abs() > rotation.abs()) {
      return GestureType.scale;
    } else if (rotation != 0.0) {
      return GestureType.rotate;
    } else {
      return GestureType.pan;
    }
  }

  /// Handles the start of a scale gesture (pan, zoom, or rotation).
  ///
  /// This method is called when the user begins a gesture interaction.
  /// It performs essential initialization including:
  ///
  /// - Stopping any active momentum animations
  /// - Resetting gesture type and axis detection
  /// - Recording initial scale, rotation, and focal point values
  /// - Calling the widget's `onInteractionStart` callback
  ///
  /// The [details] contain information about the gesture's focal point
  /// and initial properties needed for subsequent updates.
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

  /// Handles continuous updates during a scale gesture (pan, zoom, or
  /// rotation).
  ///
  /// This method processes ongoing gesture input and applies the appropriate
  /// transformation based on the detected gesture type. It:
  ///
  /// - Determines and locks the gesture type for the duration of the
  ///   interaction
  /// - Applies scale transformations for pinch-to-zoom gestures
  /// - Applies rotation transformations for two-finger twist gestures
  /// - Applies translation transformations for pan gestures
  /// - Handles axis-aligned panning when [PanAxis.aligned] is configured
  /// - Calls the widget's `onInteractionUpdate` callback
  ///
  /// The [details] contain updated information about the gesture including
  /// focal point, scale, and rotation changes.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    // The current gesture focal point in local widget coordinates
    final localFocalPoint = details.localFocalPoint;
    _scaleAnimationFocalPoint = localFocalPoint;

    // Current scale factor from the transformation matrix
    final scale = _controller.value.getMaxScaleOnAxis();
    // Focal point transformed to scene coordinates for calculations
    final focalPointScene = _controller.toScene(localFocalPoint);

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
        // Initial scale factor recorded when the gesture started
        final scaleStart = _scaleStart!;

        // Target scale factor based on gesture progression
        final desiredScale = scaleStart * details.scale;

        // Scale change ratio to apply to current transformation
        final scaleChange = desiredScale / scale;

        _controller.zoomAt(localFocalPoint, scaleChange);
        _referenceFocalPoint = _controller.toScene(localFocalPoint);

      case GestureType.rotate:
        // Current rotation angle from gesture details
        final rotation = details.rotation;
        if (rotation == 0.0) {
          widget.onInteractionUpdate?.call(details);
          return;
        }

        // Initial rotation angle recorded when the gesture started
        final rotationStart = _rotationStart!;

        // Target rotation angle based on gesture progression
        final desiredRotation = rotationStart + rotation;

        // Current rotation angle from the controller
        final currentRotation = _controller.currentRotation;

        // Rotation change to apply to the transformation matrix
        final rotationDelta = currentRotation - desiredRotation;

        // Current transformation matrix before rotation is applied
        final currentValue = _controller.value;

        _controller.value = _controller.matrixRotate(
          currentValue,
          rotationDelta,
          localFocalPoint,
        );

        _controller.currentRotation = desiredRotation;

      case GestureType.pan:
        assert(_referenceFocalPoint != null);
        if (details.scale != 1.0) {
          widget.onInteractionUpdate?.call(details);
          return;
        }

        // Reference point in scene coordinates from gesture start
        final referenceFocalPoint = _referenceFocalPoint!;
        _currentAxis ??= getPanAxis(referenceFocalPoint, focalPointScene);

        // Translation change vector in scene coordinates
        final translationChange = focalPointScene - referenceFocalPoint;

        // Current transformation matrix before translation is applied
        final currentValue = _controller.value;

        _controller.value = _controller.matrixTranslate(
          currentValue,
          translationChange,
        );

        _referenceFocalPoint = _controller.toScene(localFocalPoint);
    }
    widget.onInteractionUpdate?.call(details);
  }

  /// Determines the primary axis of movement between two points.
  ///
  /// This function analyzes the movement from [point1] to [point2] and determines
  /// whether the movement is primarily horizontal or vertical based on which
  /// component (X or Y) has the larger absolute change.
  ///
  /// This is useful for implementing axis-aligned panning behavior where the
  /// first movement determines the allowed axis for the rest of the gesture.
  ///
  /// Parameters:
  /// - [point1]: Starting point of the movement
  /// - [point2]: Ending point of the movement
  ///
  /// Returns [Axis.horizontal] if X movement is larger, [Axis.vertical] if Y
  /// movement is larger, or `null` if the points are identical.
  Axis? getPanAxis(Offset point1, Offset point2) {
    if (point1 == point2) {
      return null;
    }
    // Horizontal displacement between the two points
    final x = point2.dx - point1.dx;
    // Vertical displacement between the two points
    final y = point2.dy - point1.dy;
    return x.abs() > y.abs() ? Axis.horizontal : Axis.vertical;
  }

  /// Handles the end of a scale gesture and initiates momentum animations.
  ///
  /// Called when the user releases their gesture. This method:
  ///
  /// - Cleans up gesture tracking state
  /// - Evaluates gesture velocity to determine if momentum animation is needed
  /// - Creates and starts friction-based animations for natural deceleration
  /// - Handles both pan and scale momentum animations with physics-based motion
  /// - Calls the widget's `onInteractionEnd` callback
  ///
  /// Pan gestures with sufficient velocity will continue moving with decreasing
  /// speed. Scale gestures with velocity will continue zooming with
  /// deceleration.
  /// Rotation gestures currently do not have momentum.
  ///
  /// The [details] contain velocity information used for momentum calculations.
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
        // Current translation vector from the transformation matrix
        final translationVector = _controller.value.getTranslation();

        // Current translation as an Offset for animation calculations
        final translation = Offset(translationVector.x, translationVector.y);

        // Friction simulation for horizontal momentum with initial position and
        // velocity
        final frictionSimulationX = FrictionSimulation(
          widget.interactionEndFrictionCoefficient,
          translation.dx,
          details.velocity.pixelsPerSecond.dx,
        );

        // Friction simulation for vertical momentum with initial position and
        // velocity
        final frictionSimulationY = FrictionSimulation(
          widget.interactionEndFrictionCoefficient,
          translation.dy,
          details.velocity.pixelsPerSecond.dy,
        );

        // Total animation duration based on velocity and friction
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

        // Current scale factor from the transformation matrix
        final scale = _controller.value.getMaxScaleOnAxis();

        // Friction simulation for scale momentum with adjusted friction
        // coefficient
        final frictionSimulation = FrictionSimulation(
          widget.interactionEndFrictionCoefficient * widget.scaleFactor,
          scale,
          details.scaleVelocity / 10,
        );

        // Total animation duration for scale momentum based on velocity
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

  /// Calculates the time when a decelerating motion becomes effectively
  /// motionless.
  ///
  /// This function is used for momentum-based animations to determine when
  /// to stop the animation. It uses a logarithmic decay model where velocity
  /// decreases exponentially over time due to friction.
  ///
  /// The formula used is: t = ln(threshold/velocity) / ln(drag/100)
  ///
  /// Parameters:
  /// - [velocity]: Initial velocity magnitude (pixels per second)
  /// - [drag]: Friction coefficient (higher values = more friction)
  /// - [effectivelyMotionless]: Velocity threshold below which motion stops
  ///
  /// Returns the time in seconds when velocity drops to the threshold.
  /// Used by animation controllers for smooth momentum effects.
  double getFinalTime(
    double velocity,
    double drag, {
    double effectivelyMotionless = 10,
  }) => math.log(effectivelyMotionless / velocity) / math.log(drag / 100);

  /// Handles pointer signals from mouse scroll wheels and trackpad events.
  ///
  /// This method processes desktop input events including:
  ///
  /// - Mouse scroll wheel events (converted to zoom)
  /// - Trackpad scroll events (pan or zoom based on
  ///   `trackpadScrollCausesScale`)
  /// - Trackpad pinch events (direct scale input)
  ///
  /// Mouse wheel events are exponentially scaled to provide natural zoom
  /// behavior.
  /// Trackpad events can be configured to either pan the content (default) or
  /// zoom the content based on the `trackpadScrollCausesScale` setting.
  ///
  /// The method respects gesture support settings and calls appropriate
  /// interaction callbacks to maintain consistency with touch gestures.
  ///
  /// The [event] contains position and delta information for the pointer
  /// signal.
  void _receivedPointerSignal(PointerSignalEvent event) {
    // Event position in local widget coordinates
    final local = event.localPosition;
    // Event position in global screen coordinates
    final global = event.position;
    // Scale change factor to be calculated based on event type
    final double scaleChange;

    if (event is PointerScrollEvent) {
      // Whether the input device is a trackpad (vs mouse wheel)
      final isTrackpad = event.kind == PointerDeviceKind.trackpad;
      // User preference for trackpad scroll behavior (pan vs scale)
      final trackpadScrollCausesScale = widget.trackpadScrollCausesScale;

      if (isTrackpad && !trackpadScrollCausesScale) {
        widget.onInteractionStart?.call(
          ScaleStartDetails(focalPoint: global, localFocalPoint: local),
        );

        // Raw scroll delta from the trackpad in global coordinates
        final scrollDelta = event.scrollDelta;
        // Scroll delta transformed to local widget coordinates
        final localDelta = PointerEvent.transformDeltaViaPositions(
          untransformedEndPosition: global + scrollDelta,
          untransformedDelta: scrollDelta,
          transform: event.transform,
        );

        if (!_gestureIsSupported(GestureType.pan)) {
          // Adjusted global position for callback consistency
          final adjustedGlobal = global - scrollDelta;

          // Adjusted local position for callback consistency
          final adjustedLocal = local - scrollDelta;

          widget.onInteractionUpdate?.call(
            ScaleUpdateDetails(
              focalPoint: adjustedGlobal,
              localFocalPoint: adjustedLocal,
              focalPointDelta: -localDelta,
            ),
          );

          widget.onInteractionEnd?.call(ScaleEndDetails());
          return;
        }

        _controller.panFromLocalTo(local, local - localDelta);

        // Adjusted positions for final callback after pan operation
        final adjustedGlobal = global - scrollDelta;
        final adjustedLocal = local - scrollDelta;

        widget.onInteractionUpdate?.call(
          ScaleUpdateDetails(
            focalPoint: adjustedGlobal,
            localFocalPoint: adjustedLocal,
            focalPointDelta: -localDelta,
          ),
        );

        widget.onInteractionEnd?.call(ScaleEndDetails());
        return;
      }

      // Vertical scroll component for mouse wheel/trackpad zoom
      final scrollDeltaY = event.scrollDelta.dy;

      if (scrollDeltaY == 0.0) {
        return;
      }

      // Sensitivity factor for scroll wheel to scale conversion
      final scaleFactor = widget.scaleFactor;

      // Exponential scale change based on scroll distance
      scaleChange = math.exp(-scrollDeltaY / scaleFactor);
    } else if (event is PointerScaleEvent) {
      // Direct scale value from trackpad pinch gestures
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

    _controller.zoomAt(local, scaleChange);

    widget.onInteractionUpdate?.call(
      ScaleUpdateDetails(
        focalPoint: global,
        localFocalPoint: local,
        scale: scaleChange,
      ),
    );

    widget.onInteractionEnd?.call(ScaleEndDetails());
  }

  /// Animation listener for pan momentum (inertia) animations.
  ///
  /// Called on each frame during pan momentum animation to apply the smooth
  /// deceleration effect. This method:
  ///
  /// - Checks if the animation is still active
  /// - Applies the interpolated translation from the animation
  /// - Cleans up when the animation completes
  /// - Resets gesture state when momentum ends
  ///
  /// The animation interpolates between the initial translation and the final
  /// position calculated by the friction simulation, providing natural
  /// deceleration that feels responsive and predictable.
  void _handleInertiaAnimation() {
    if (!_animationController.isAnimating) {
      _currentAxis = null;
      _animation?.removeListener(_handleInertiaAnimation);
      _animation = null;
      _animationController.reset();
      return;
    }

    // Current translation vector from the transformation matrix
    final translationVector = _controller.value.getTranslation();

    // Offset representation of the current translation for animation
    // calculations
    final translation = Offset(translationVector.x, translationVector.y);

    _controller.value = _controller.matrixTranslate(
      _controller.value,
      _controller.toScene(_animation!.value) - _controller.toScene(translation),
    );
  }

  /// Animation listener for scale momentum animations.
  ///
  /// Called on each frame during scale momentum animation to apply smooth
  /// zoom deceleration. This method:
  ///
  /// - Checks if the scale animation is still active
  /// - Calculates the scale change from the animated value
  /// - Applies the scale change around the stored focal point
  /// - Cleans up when the animation completes
  ///
  /// The scale momentum maintains the focal point where the user's gesture
  /// ended, ensuring that the zoom deceleration feels natural and the content
  /// under the gesture point remains stable.
  void _handleScaleAnimation() {
    if (!_scaleAnimationController.isAnimating) {
      _currentAxis = null;
      _scaleAnimation?.removeListener(_handleScaleAnimation);
      _scaleAnimation = null;
      _scaleAnimationController.reset();
      return;
    }

    // Target scale value from the ongoing scale momentum animation
    final desiredScale = _scaleAnimation!.value;

    // Ratio of the new scale to current scale, used for applying zoom change
    final scaleChange = desiredScale / _controller.value.getMaxScaleOnAxis();

    _controller.zoomAt(_scaleAnimationFocalPoint, scaleChange);
  }
}

/// Internal widget that applies transformations and handles child presentation.
///
/// This private widget is responsible for applying the transformation matrix
/// to the child widget and managing constraint behavior. It serves as the
/// final rendering layer that:
///
/// - Applies the transformation matrix (translation, scale, rotation)
/// - Handles constrained vs unconstrained layout behavior
/// - Provides clipping to prevent visual overflow
/// - Maintains a key reference for size calculations
///
/// Used internally by [InteractiveViewerPlus] to separate the gesture handling
/// logic from the actual transformation application and child rendering.
class _InteractiveViewerBuilt extends StatelessWidget {
  /// The child widget to be transformed and displayed.
  ///
  /// This is the actual content that will have transformations applied to it.
  /// Can be any widget provided by the user or built by the builder function.
  final Widget child;

  /// Global key for accessing the child widget's render object.
  ///
  /// Used by the parent [_InteractiveViewerPlusState] to get the child's
  /// dimensions for boundary calculations and constraint enforcement.
  final GlobalKey childKey;

  /// Clipping behavior for content that extends beyond the viewport bounds.
  ///
  /// Determines how content is clipped when it extends outside the visible
  /// area.
  /// Applied via [ClipRect] to ensure clean visual boundaries.
  final Clip clipBehavior;

  /// Whether the child should be constrained to the viewport size.
  ///
  /// When `true`, the child is constrained within the viewport dimensions.
  /// When `false`, the child can extend infinitely in all directions via
  /// [OverflowBox], which is useful for builder patterns and infinite content.
  final bool constrained;

  /// The transformation matrix to apply to the child.
  ///
  /// Contains the combined transformation state including translation (pan),
  /// scale (zoom), and rotation. This matrix is computed by the controller
  /// and represents the user's current view transformation.
  final Matrix4 matrix;

  /// The alignment point for transformation operations.
  ///
  /// Specifies the point around which transformations are applied. This is
  /// typically the focal point of gestures to ensure intuitive behavior
  /// where the content under the user's finger remains stable during scaling.
  final Alignment? alignment;

  /// Creates an internal widget for applying transformations to the child.
  ///
  /// All parameters are required and represent the current state needed
  /// to properly transform and display the child widget.
  const _InteractiveViewerBuilt({
    required this.child,
    required this.childKey,
    required this.clipBehavior,
    required this.constrained,
    required this.matrix,
    required this.alignment,
  });

  /// Builds the transformed child widget with appropriate constraints and
  /// clipping.
  ///
  /// This method creates the final widget tree by:
  ///
  /// 1. Wrapping the child in a [KeyedSubtree] for stable identity
  /// 2. Applying the transformation matrix via [Transform]
  /// 3. Optionally wrapping in [OverflowBox] for unconstrained layout
  /// 4. Applying clipping via [ClipRect] to prevent visual overflow
  ///
  /// The structure ensures that transformations are applied correctly while
  /// maintaining proper layout constraints and visual boundaries.
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
