/// @docImport '../src/interactive_viewer_plus.dart';
library;

import 'dart:ui';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

import 'helper_methods.dart';

/// A controller for [InteractiveViewerPlus] that manages the transformation
/// matrix and provides programmatic control over pan, zoom, and rotation.
///
/// A thin wrapper on [ValueNotifier] whose value is a [Matrix4] representing a
/// transformation.
///
/// The [value] defaults to the identity matrix, which corresponds to no
/// transformation.
///
/// Example usage:
/// ```dart
/// final controller = InteractiveViewerPlusController();
///
/// // Zoom in by 20%
/// controller.zoom(1.2);
///
/// // Pan by 50 pixels horizontally
/// controller.pan(Offset(50, 0));
///
/// // Rotate by 45 degrees (π/4 radians)
/// controller.rotate(math.pi / 4);
///
/// // Flip horizontally
/// controller.flip(flipX: true);
/// ```
/// See also:
///
///  * [InteractiveViewerPlus.controller] for detailed documentation
///    on how to use InteractiveViewerPlusController with
///    [InteractiveViewerPlus].
class InteractiveViewerPlusController extends ValueNotifier<Matrix4> {
  /// The current rotation angle in radians.
  double currentRotation = 0;

  /// The minimum scale factor allowed.
  late double minScale;

  /// The maximum scale factor allowed.
  late double maxScale;

  /// The current axis for aligned panning, if any.
  Axis? currentAxis;

  /// The current pan axis constraint.
  late PanAxis panAxis;

  /// The viewport rectangle in local coordinates.
  late Rect viewport;

  /// The boundary rectangle that constrains the transformations.
  late Rect boundaryRect;

  /// Creates an [InteractiveViewerPlusController] with an optional initial
  /// transformation matrix.
  ///
  /// If [value] is not provided, an identity matrix is used.
  InteractiveViewerPlusController([Matrix4? value])
    : super(value ?? Matrix4.identity());

  /// Sets internal values used by the controller.
  ///
  /// This method is typically called by the [InteractiveViewerPlus] widget
  /// to configure the controller's constraints and viewport information.
  void setValues({
    required Rect viewport,
    required double minScale,
    required double maxScale,
    required PanAxis panAxis,
    required Rect boundaryRect,
    required Axis? currentAxis,
  }) {
    this.panAxis = panAxis;
    this.viewport = viewport;
    this.minScale = minScale;
    this.maxScale = maxScale;
    this.currentAxis = currentAxis;
    this.boundaryRect = boundaryRect;
  }

  /// Translates the current view by the given [offset].
  ///
  /// The translation respects boundary constraints and pan axis restrictions.
  ///
  /// Example:
  /// ```dart
  /// // Pan 50 pixels to the right and 30 pixels down
  /// controller.pan(Offset(50, 30));
  /// ```
  void pan(Offset offset) {
    value = matrixTranslate(value, offset);
  }

  /// Scales the current view by the given [scale] factor.
  ///
  /// The scaling respects the [minScale] and [maxScale] constraints.
  /// A scale of 1.0 means no change, values greater than 1.0 zoom in,
  /// and values less than 1.0 zoom out.
  ///
  /// Example:
  /// ```dart
  /// // Zoom in by 20%
  /// controller.zoom(1.2);
  ///
  /// // Zoom out by 20%
  /// controller.zoom(0.8);
  /// ```
  void zoom(double scale) {
    value = matrixScale(value, scale);
  }

  /// Scales the view by [scaleChange] around the given [viewportLocal] point.
  ///
  /// This method ensures that the content at [viewportLocal] stays in the same
  /// position after scaling, creating a zoom-to-point effect.
  ///
  /// Example:
  /// ```dart
  /// // Zoom in 1.5x around the center of the viewport
  /// controller.zoomAt(viewport.center, 1.5);
  /// ```
  void zoomAt(Offset viewportLocal, double scaleChange) {
    // The point in scene coordinates before scaling, used as reference
    final reference = toScene(viewportLocal);
    value = matrixScale(value, scaleChange);
    // The same viewport point in scene coordinates after scaling
    final after = toScene(viewportLocal);
    value = matrixTranslate(value, after - reference);
  }

  /// Pans the view so that the content at [fromLocal] moves to [toLocal].
  ///
  /// This is useful for implementing drag-to-pan functionality.
  ///
  /// Example:
  /// ```dart
  /// // Pan from one point to another
  /// controller.panFromLocalTo(gestureStart, gestureEnd);
  /// ```
  void panFromLocalTo(Offset fromLocal, Offset toLocal) {
    // Scene coordinate of the starting viewport position
    final a = toScene(fromLocal);
    // Scene coordinate of the target viewport position
    final b = toScene(toLocal);
    value = matrixTranslate(value, b - a);
  }

  /// Flips the content horizontally and/or vertically around the viewport center.
  ///
  /// Set [flipX] to true to flip horizontally, and [flipY] to true to flip
  /// vertically. Both can be true to flip in both directions.
  ///
  /// Example:
  /// ```dart
  /// // Flip horizontally
  /// controller.flip(flipX: true);
  ///
  /// // Flip vertically
  /// controller.flip(flipY: true);
  ///
  /// // Flip both ways
  /// controller.flip(flipX: true, flipY: true);
  /// ```
  void flip({bool flipX = false, bool flipY = false}) {
    value = matrixFlip(
      value,
      flipX: flipX,
      flipY: flipY,
      focalPoint: viewport.center,
    );
  }

  /// Rotates the content by [deltaRotation] radians around the viewport center.
  ///
  /// Positive values rotate counter-clockwise, negative values rotate
  /// clockwise.
  ///
  /// Example:
  /// ```dart
  /// // Rotate 45 degrees counter-clockwise
  /// controller.rotate(math.pi / 4);
  ///
  /// // Rotate 90 degrees clockwise
  /// controller.rotate(-math.pi / 2);
  /// ```
  void rotate(double deltaRotation) {
    value = matrixRotate(value, deltaRotation, viewport.center);
    currentRotation += deltaRotation;
  }

  /// Return the scene point at the given viewport point.
  ///
  /// A viewport point is relative to the parent while a scene point is relative
  /// to the child, regardless of transformation. Calling toScene with a
  /// viewport point essentially returns the scene coordinate that lies
  /// underneath the viewport point given the transform.
  ///
  /// The viewport transforms as the inverse of the child (i.e. moving the child
  /// left is equivalent to moving the viewport right).
  ///
  /// This method is often useful when determining where an event on the parent
  /// occurs on the child. This example shows how to determine where a tap on
  /// the parent occurred on the child.
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   return GestureDetector(
  ///     onTapUp: (TapUpDetails details) {
  ///       _childWasTappedAt = _transformationController.toScene(
  ///         details.localPosition,
  ///       );
  ///     },
  ///     child: InteractiveViewer(
  ///       transformationController: _transformationController,
  ///       child: child,
  ///     ),
  ///   );
  /// }
  /// ````
  Offset toScene(Offset viewportPoint) {
    // On viewportPoint, perform the inverse transformation of the scene to get
    // where the point would be in the scene before the transformation.

    // Inverse of the current transformation matrix for coordinate conversion
    final inverseMatrix = Matrix4.inverted(value);
    // The point transformed from viewport to scene coordinates as Vector3
    final untransformed = inverseMatrix.transform3(
      Vector3(viewportPoint.dx, viewportPoint.dy, 0),
    );
    return Offset(untransformed.x, untransformed.y);
  }

  /// Internal method to apply rotation transformation around a focal point.
  ///
  /// This creates a new transformation matrix that applies rotation around
  /// the specified [focalPoint] in scene coordinates. The rotation is applied
  /// by translating to the focal point, rotating, then translating back.
  ///
  /// Returns a new [Matrix4] with rotation applied.
  /// Returns the original matrix if [rotation] is zero.
  Matrix4 matrixRotate(Matrix4 matrix, double rotation, Offset focalPoint) {
    if (rotation == 0) {
      return matrix.clone();
    }
    // The focal point converted to scene coordinates for rotation center
    final focalPointScene = toScene(focalPoint);
    // X coordinate of the rotation center in scene space
    final dx = focalPointScene.dx;
    // Y coordinate of the rotation center in scene space
    final dy = focalPointScene.dy;

    return matrix.clone()
      ..translateByDouble(dx, dy, 0, 1)
      ..rotateZ(-rotation)
      ..translateByDouble(-dx, -dy, 0, 1);
  }

  /// Internal method to apply scale transformation with boundary constraints.
  ///
  /// This method applies scaling while respecting the minimum and maximum scale
  /// limits and ensuring the content doesn't become smaller than the viewport
  /// when boundary constraints are active.
  ///
  /// The method calculates the minimum required scale to fill the viewport,
  /// then clamps the desired scale within the allowed range.
  ///
  /// Returns a new [Matrix4] with constrained scaling applied.
  /// Returns the original matrix if [scale] is 1.0.
  ///
  /// Throws [AssertionError] if [scale] is zero.
  Matrix4 matrixScale(Matrix4 matrix, double scale) {
    if (scale == 1.0) {
      return matrix.clone();
    }
    assert(scale != 0.0);

    // Current scale factor extracted from the transformation matrix

    // Don't allow a scale that results in an overall scale beyond min/max
    // scale.
    final currentScale = value.getMaxScaleOnAxis();

    // Width of the viewport area in logical pixels
    final viewportWidth = viewport.width;
    // Height of the viewport area in logical pixels
    final viewportHeight = viewport.height;

    // Width of the boundary rectangle that constrains content
    final boundaryWidth = boundaryRect.width;
    // Height of the boundary rectangle that constrains content
    final boundaryHeight = boundaryRect.height;

    // Minimum scale required to fill viewport (prevents content smaller than
    // viewport)
    final minRequiredScale = math.max(
      // Ensure that the scale cannot make the child so big that it can't fit
      // inside the boundaries (in either direction).
      viewportWidth / boundaryWidth,
      viewportHeight / boundaryHeight,
    );

    // Total scale that would result from applying the requested scale factor
    final desiredTotalScale = currentScale * scale;

    // Ensure scale doesn't go below minimum required to fill viewport
    final totalScale = math.max(desiredTotalScale, minRequiredScale);

    // Clamp the total scale within the allowed min/max range
    final clampedTotalScale = clampDouble(totalScale, minScale, maxScale);

    // Calculate the actual scale factor to apply relative to current scale
    final clampedScale = clampedTotalScale / currentScale;

    return matrix.clone()
      ..scaleByDouble(clampedScale, clampedScale, clampedScale, 1);
  }

  /// Internal method to apply flip transformation with boundary correction.
  ///
  /// This method applies horizontal and/or vertical flipping around the
  /// specified focal point. The flip operation accounts for any existing
  /// rotation by applying the flip in the original orientation, then
  /// restoring the rotation.
  ///
  /// After flipping, the result is checked against boundary constraints
  /// and corrected if necessary.
  ///
  /// Returns a new [Matrix4] with flip transformation and boundary correction
  /// applied.
  /// Returns the original matrix if neither [flipX] nor [flipY] is true.
  Matrix4 matrixFlip(
    Matrix4 matrix, {
    required bool flipX,
    required bool flipY,
    required Offset focalPoint,
  }) {
    if (!flipX && !flipY) {
      return matrix.clone();
    }

    // Scale factor for X axis: -1 for flip, 1 for no flip
    final sx = flipX ? -1.0 : 1.0;
    // Scale factor for Y axis: -1 for flip, 1 for no flip
    final sy = flipY ? -1.0 : 1.0;
    // The focal point converted to scene coordinates for flip center
    final focalPointScene = toScene(focalPoint);
    // X coordinate of the flip center in scene space
    final dx = focalPointScene.dx;
    // Y coordinate of the flip center in scene space
    final dy = focalPointScene.dy;

    // Candidate matrix with flip transformation applied around focal point
    final candidate = matrix.clone()
      ..translateByDouble(dx, dy, 0, 1)
      ..rotateZ(currentRotation)
      ..scaleByDouble(sx, sy, 1, 1)
      ..rotateZ(-currentRotation)
      ..translateByDouble(-dx, -dy, 0, 1);

    return _correctForBoundary(original: matrix, candidate: candidate);
  }

  /// Internal method to apply translation with axis alignment and boundary
  /// correction.
  ///
  /// This method applies translation while respecting pan axis constraints
  /// and boundary limits. If a current axis is set, the translation is
  /// aligned to that axis, potentially rotated based on the current rotation.
  ///
  /// After translation, the result is checked against boundary constraints
  /// and corrected if necessary.
  ///
  /// Returns a new [Matrix4] with translation and boundary correction applied.
  /// Returns the original matrix if [translation] is zero.
  Matrix4 matrixTranslate(Matrix4 matrix, Offset translation) {
    if (translation == Offset.zero) {
      return matrix.clone();
    }

    // Translation adjusted for axis alignment constraints based on panAxis
    // setting
    final Offset alignedTranslation;

    if (currentAxis != null) {
      alignedTranslation = switch (panAxis) {
        PanAxis.horizontal => alignAxis(
          translation,
          Axis.horizontal,
          currentRotation,
        ),
        PanAxis.vertical => alignAxis(
          translation,
          Axis.vertical,
          currentRotation,
        ),
        PanAxis.aligned => alignAxis(
          translation,
          currentAxis!,
          currentRotation,
        ),
        PanAxis.free => translation,
      };
    } else {
      alignedTranslation = translation;
    }

    // Candidate matrix with translation applied, subject to boundary correction
    final candidate = matrix.clone()
      ..translateByDouble(alignedTranslation.dx, alignedTranslation.dy, 0, 1);

    return _correctForBoundary(original: matrix, candidate: candidate);
  }

  /// Internal method to correct transformations that violate boundary
  /// constraints.
  ///
  /// This method takes a candidate transformation matrix and ensures it
  /// respects the boundary constraints. If the transformation would place
  /// content outside the allowed boundaries, it calculates a corrected
  /// transformation that brings the content back within bounds while minimizing
  /// the deviation from the intended transformation.
  ///
  /// The correction algorithm works by:
  /// 1. Checking if the candidate transformation violates boundaries
  /// 2. If so, calculating the minimum correction needed
  /// 3. Applying corrections on each axis independently when possible
  /// 4. Falling back to the original transformation if correction fails
  ///
  /// Parameters:
  /// - [original]: The original transformation matrix before the change
  /// - [candidate]: The proposed new transformation matrix to validate
  ///
  /// Returns a [Matrix4] that respects boundary constraints.
  /// Returns [candidate] if boundaries are infinite or no correction is needed.
  /// Returns [original] if correction fails on both axes simultaneously.
  Matrix4 _correctForBoundary({
    required Matrix4 original,
    required Matrix4 candidate,
  }) {
    if (boundaryRect.isInfinite) {
      return candidate;
    }

    // Viewport transformed by the candidate matrix to check boundary violations
    //
    //Transform the viewport to determine where its four corners will be after
    // the child has been transformed.
    final nextViewport = transformViewport(candidate, viewport);

    // Axis-aligned bounding box of boundary rect, adjusted for current rotation

    // Find the axis aligned bounding box for the rect rotated about its center
    // by the given amount.
    final boundariesAabbQuad = getAxisAlignedBoundingBoxWithRotation(
      boundaryRect,
      currentRotation,
    );

    // Distance by which the viewport exceeds boundary limits (zero if within
    // bounds)
    final offendingDistance = exceedsBy(boundariesAabbQuad, nextViewport);

    // If the boundaries are infinite, then no need to check if the translation
    // fits within them.
    if (offendingDistance == Offset.zero) {
      return candidate;
    }

    // Current translation vector from the candidate transformation matrix
    final nextTotalTranslation = getMatrixTranslation(candidate);

    // X component of the boundary violation distance
    final offendingDx = offendingDistance.dx;
    // Y component of the boundary violation distance
    final offendingDy = offendingDistance.dy;

    // Current scale factor from the candidate matrix
    final currentScale = candidate.getMaxScaleOnAxis();

    // Translation adjusted to correct boundary violations
    final correctedTotalTranslation = Offset(
      nextTotalTranslation.dx - offendingDx * currentScale,
      nextTotalTranslation.dy - offendingDy * currentScale,
    );

    // Matrix with corrected translation applied
    final correctedMatrix = candidate.clone()
      ..setTranslation(
        Vector3(correctedTotalTranslation.dx, correctedTotalTranslation.dy, 0),
      );

    // Viewport after applying the corrected transformation
    final correctedViewport = transformViewport(correctedMatrix, viewport);

    // Check if correction resolved all boundary violations
    final offendingCorrectedDistance = exceedsBy(
      boundariesAabbQuad,
      correctedViewport,
    );

    if (offendingCorrectedDistance == Offset.zero) {
      return correctedMatrix;
    }

    // X component of remaining boundary violations after correction
    final correctedOffendingDx = offendingCorrectedDistance.dx;
    // Y component of remaining boundary violations after correction
    final correctedOffendingDy = offendingCorrectedDistance.dy;

    if (correctedOffendingDx != 0.0 && correctedOffendingDy != 0.0) {
      return original;
    }

    // Original translation vector before any modifications
    final originalTranslation = getMatrixTranslation(original);
    // X component of the original translation
    final originalDx = originalTranslation.dx;
    // Y component of the original translation
    final originalDy = originalTranslation.dy;

    // X component of the corrected translation
    final correctedDx = correctedTotalTranslation.dx;
    // Y component of the corrected translation
    final correctedDy = correctedTotalTranslation.dy;

    // Final translation using corrected values where possible, original where
    // correction failed
    final finalTranslation = Offset(
      correctedOffendingDx == 0.0 ? correctedDx : originalDx,
      correctedOffendingDy == 0.0 ? correctedDy : originalDy,
    );

    return candidate.clone()
      ..setTranslation(Vector3(finalTranslation.dx, finalTranslation.dy, 0));
  }
}
