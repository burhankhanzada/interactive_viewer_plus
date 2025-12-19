/// @docImport '../src/interactive_viewer_plus.dart';
library;

import 'dart:ui';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

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

  /// Aligns an offset to a specific axis, optionally accounting for rotation.
  ///
  /// This function constrains the given [offset] to move only along the specified
  /// [axis]. When [rotation] is provided, the axis is rotated by that amount,
  /// allowing for axis-aligned movement even when the content is rotated.
  ///
  /// For example, if the content is rotated 45 degrees and the horizontal axis
  /// is specified, the returned offset will be aligned with the rotated
  /// horizontal
  /// direction rather than the screen horizontal.
  ///
  /// Parameters:
  /// - [offset]: The original offset to align
  /// - [axis]: The axis to align to (horizontal or vertical)
  /// - [rotation]: Optional rotation angle in radians (default: 0)
  ///
  /// Returns an [Offset] constrained to the specified axis.
  Offset alignAxis(Offset offset, Axis axis, [double rotation = 0]) {
    if (rotation == 0) {
      return switch (axis) {
        Axis.horizontal => Offset(offset.dx, 0),
        Axis.vertical => Offset(0, offset.dy),
      };
    }

    // Unit vector representing the axis direction after rotation
    final axisDirection = switch (axis) {
      Axis.horizontal => Offset(math.cos(rotation), math.sin(rotation)),
      Axis.vertical => Offset(-math.sin(rotation), math.cos(rotation)),
    };

    // Projection of the offset onto the rotated axis direction
    final dotProduct =
        offset.dx * axisDirection.dx + offset.dy * axisDirection.dy;

    return Offset(dotProduct * axisDirection.dx, dotProduct * axisDirection.dy);
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

  /// Computes the axis-aligned bounding box of a rectangle after rotation.
  ///
  /// This function takes a [rect] and applies the given [rotation] around its
  /// center,
  /// then calculates the axis-aligned bounding box that contains the rotated
  /// rectangle.
  /// This is useful for boundary calculations when content can be rotated.
  ///
  /// The rotation is applied around the rectangle's center point, and the
  /// resulting bounding box represents the minimum axis-aligned rectangle
  /// that fully contains the rotated original rectangle.
  ///
  /// Parameters:
  /// - [rect]: The original rectangle before rotation
  /// - [rotation]: Rotation angle in radians (positive = counter-clockwise)
  ///
  /// Returns a [Quad] representing the axis-aligned bounding box of the
  /// rotated rectangle.
  Quad getAxisAlignedBoundingBoxWithRotation(Rect rect, double rotation) {
    // Transformation matrix that rotates around the rectangle's center point
    final rotationMatrix = Matrix4.identity()
      ..translateByDouble(rect.size.width / 2, rect.size.height / 2, 0, 1)
      ..rotateZ(rotation)
      ..translateByDouble(-rect.size.width / 2, -rect.size.height / 2, 0, 1);

    // Quadrilateral representing the rectangle's corners after rotation
    final boundariesRotated = Quad.points(
      rotationMatrix.transform3(Vector3(rect.left, rect.top, 0)),
      rotationMatrix.transform3(Vector3(rect.right, rect.top, 0)),
      rotationMatrix.transform3(Vector3(rect.right, rect.bottom, 0)),
      rotationMatrix.transform3(Vector3(rect.left, rect.bottom, 0)),
    );
    return getAxisAlignedBoundingBox(boundariesRotated);
  }

  /// Computes the axis-aligned bounding box (AABB) of a quadrilateral.
  ///
  /// This function finds the smallest rectangle aligned with the coordinate axes
  /// that completely contains the given [quad]. The resulting quad represents
  /// this bounding box with corners at (minX, minY), (maxX, minY),
  /// (maxX, maxY), and (minX, maxY).
  ///
  /// Parameters:
  /// - [quad]: The input quadrilateral to compute the bounding box for
  ///
  /// Returns a new [Quad] representing the axis-aligned bounding box.
  /// The returned quad has its corners ordered as: bottom-left, bottom-right,
  /// top-right, top-left.
  ///
  /// This function is visible for testing boundary calculations.
  Quad getAxisAlignedBoundingBox(Quad quad) {
    // Minimum X coordinate among all quad points (leftmost edge)
    final double minX = math.min(
      quad.point0.x,
      math.min(quad.point1.x, math.min(quad.point2.x, quad.point3.x)),
    );
    // Minimum Y coordinate among all quad points (topmost edge)
    final double minY = math.min(
      quad.point0.y,
      math.min(quad.point1.y, math.min(quad.point2.y, quad.point3.y)),
    );
    // Maximum X coordinate among all quad points (rightmost edge)
    final double maxX = math.max(
      quad.point0.x,
      math.max(quad.point1.x, math.max(quad.point2.x, quad.point3.x)),
    );
    // Maximum Y coordinate among all quad points (bottommost edge)
    final double maxY = math.max(
      quad.point0.y,
      math.max(quad.point1.y, math.max(quad.point2.y, quad.point3.y)),
    );
    return Quad.points(
      Vector3(minX, minY, 0),
      Vector3(maxX, minY, 0),
      Vector3(maxX, maxY, 0),
      Vector3(minX, maxY, 0),
    );
  }

  /// Calculates by how much a viewport exceeds the allowed boundary.
  ///
  /// This function determines if any corners of the [viewport] quad lie outside
  /// the [boundary] quad, and if so, returns the offset needed to bring the
  /// viewport back within bounds.
  ///
  /// It checks each corner of the viewport and finds the largest exceedance
  /// in both X and Y directions. The result indicates how far and in which
  /// direction the viewport needs to be moved to respect the boundary
  /// constraints.
  ///
  /// Parameters:
  /// - [boundary]: The allowed boundary area
  /// - [viewport]: The current viewport area to check
  ///
  /// Returns an [Offset] indicating the correction needed. Zero offset means
  /// the viewport is within bounds. Non-zero values indicate the distance
  /// and direction the viewport exceeds the boundary.
  Offset exceedsBy(Quad boundary, Quad viewport) {
    // Array of all four corner points of the viewport quadrilateral
    final viewportPoints = <Vector3>[
      viewport.point0,
      viewport.point1,
      viewport.point2,
      viewport.point3,
    ];
    // Tracks the largest boundary violation found across all viewport corners
    var largestExcess = Offset.zero;

    for (final point in viewportPoints) {
      // Nearest valid point within the boundary for this viewport corner
      final pointInside = getNearestPointInside(point, boundary);

      // Vector from viewport corner to its corrected position within boundary
      final excess = Offset(pointInside.x - point.x, pointInside.y - point.y);

      if (excess.dx.abs() > largestExcess.dx.abs()) {
        largestExcess = Offset(excess.dx, largestExcess.dy);
      }

      if (excess.dy.abs() > largestExcess.dy.abs()) {
        largestExcess = Offset(largestExcess.dx, excess.dy);
      }
    }

    return round(largestExcess);
  }

  /// Finds the nearest point inside or on the boundary of a quadrilateral.
  ///
  /// If the [point] is already inside the [quad], it returns the point unchanged.
  /// Otherwise, it finds the closest point on the quad's perimeter by checking
  /// all four edges and returning the nearest point among them.
  ///
  /// This function is crucial for boundary constraint calculations, ensuring
  /// that points stay within specified bounds.
  ///
  /// Parameters:
  /// - [point]: The target point that may be outside the quad
  /// - [quad]: The quadrilateral boundary to constrain to
  ///
  /// Returns the nearest point that lies within or on the quad's boundary.
  /// If the input point is already inside, returns the input point.
  ///
  /// This function is visible for testing constraint calculations.
  Vector3 getNearestPointInside(Vector3 point, Quad quad) {
    if (pointIsInside(point, quad)) {
      return point;
    }

    // Closest points on each of the four edges of the quadrilateral
    final closestPoints = <Vector3>[
      getNearestPointOnLine(point, quad.point0, quad.point1),
      getNearestPointOnLine(point, quad.point1, quad.point2),
      getNearestPointOnLine(point, quad.point2, quad.point3),
      getNearestPointOnLine(point, quad.point3, quad.point0),
    ];
    // Minimum distance found so far during iteration
    var minDistance = double.infinity;
    // The closest point overall among all edge candidates
    late Vector3 closestOverall;
    for (final closePoint in closestPoints) {
      // Euclidean distance from target point to current edge candidate
      final distance = math.sqrt(
        math.pow(point.x - closePoint.x, 2) +
            math.pow(point.y - closePoint.y, 2),
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestOverall = closePoint;
      }
    }
    return closestOverall;
  }

  /// Determines whether a point lies inside a quadrilateral.
  ///
  /// This function uses a dot product algorithm to check if the given [point]
  /// is contained within the [quad]. The quad is assumed to be convex and
  /// the points should be ordered consistently (either clockwise or
  /// counter-clockwise).
  ///
  /// The algorithm works by expressing the point relative to one corner of the
  /// quad and checking if it lies within the parallelogram formed by two
  /// adjacent edges.
  ///
  /// Parameters:
  /// - [point]: The point to test for containment
  /// - [quad]: The quadrilateral boundary to test against
  ///
  /// Returns `true` if the point is inside the quad, `false` otherwise.
  ///
  /// This function is visible for testing boundary calculations.
  bool pointIsInside(Vector3 point, Quad quad) {
    // Vector from quad corner (point0) to the test point
    final aM = point - quad.point0;
    // Vector from quad corner (point0) to adjacent corner (point1)
    final aB = quad.point1 - quad.point0;
    // Vector from quad corner (point0) to adjacent corner (point3)
    final aD = quad.point3 - quad.point0;

    // Dot product of point vector with first edge vector
    final aMAB = aM.dot(aB);
    // Squared length of first edge vector
    final aBAB = aB.dot(aB);
    // Dot product of point vector with second edge vector
    final aMAD = aM.dot(aD);
    // Squared length of second edge vector
    final aDAD = aD.dot(aD);

    return 0 <= aMAB && aMAB <= aBAB && 0 <= aMAD && aMAD <= aDAD;
  }

  /// Finds the nearest point on a line segment to a given point.
  ///
  /// This method calculates the projection of [point] onto the line segment
  /// defined by [l1] and [l2], clamped to the segment boundaries.
  ///
  /// The algorithm uses vector projection: for a point P and line segment AB,
  /// it finds the point on AB that is closest to P. If the projection falls
  /// outside the segment, the nearest endpoint is returned.
  ///
  /// Parameters:
  /// - [point]: The target point to find the nearest point to
  /// - [l1]: First endpoint of the line segment
  /// - [l2]: Second endpoint of the line segment
  ///
  /// Returns the nearest point on the line segment in 3D coordinates.
  /// If [l1] and [l2] are identical, returns [l1].
  ///
  /// This function is visible for testing geometric calculations.
  Vector3 getNearestPointOnLine(Vector3 point, Vector3 l1, Vector3 l2) {
    // Squared length of the line segment (avoids sqrt for performance)
    final lengthSquared =
        math.pow(l2.x - l1.x, 2.0).toDouble() +
        math.pow(l2.y - l1.y, 2.0).toDouble();

    if (lengthSquared == 0) {
      return l1;
    }

    // Vector from line start (l1) to the target point
    final l1P = point - l1;
    // Vector representing the line segment from l1 to l2
    final l1L2 = l2 - l1;
    // Normalized position along the line segment (0-1) where projection occurs
    final fraction = clampDouble(l1P.dot(l1L2) / lengthSquared, 0, 1);
    return l1 + l1L2 * fraction;
  }

  /// Rounds an offset to prevent floating-point precision errors.
  ///
  /// This function rounds both the X and Y components of an [offset] to
  /// 9 decimal places to avoid accumulation of floating-point errors
  /// in geometric calculations.
  ///
  /// Parameters:
  /// - [offset]: The offset to round
  ///
  /// Returns a new [Offset] with rounded coordinates.
  Offset round(Offset offset) => Offset(
    double.parse(offset.dx.toStringAsFixed(9)),
    double.parse(offset.dy.toStringAsFixed(9)),
  );

  /// Extracts the translation component from a transformation matrix as an
  /// Offset.
  ///
  /// This utility function converts the 3D translation vector from a [Matrix4]
  /// into a 2D [Offset] by taking only the X and Y components.
  ///
  /// Parameters:
  /// - [matrix]: The transformation matrix to extract translation from
  ///
  /// Returns an [Offset] representing the X and Y translation values.
  /// The Z component is ignored as this package works in 2D space.
  Offset getMatrixTranslation(Matrix4 matrix) {
    // 3D translation vector extracted from the transformation matrix
    final nextTranslation = matrix.getTranslation();
    return Offset(nextTranslation.x, nextTranslation.y);
  }

  // Transform the four corners of the viewport by the inverse of the given
  // matrix. This gives the viewport after the child has been transformed by the
  // given matrix. The viewport transforms as the inverse of the child (i.e.
  // moving the child left is equivalent to moving the viewport right).
  Quad transformViewport(Matrix4 matrix, Rect viewport) {
    final inverseMatrix = Matrix4.inverted(matrix);
    return Quad.points(
      vecot3FromOffset(inverseMatrix, viewport.topLeft),
      vecot3FromOffset(inverseMatrix, viewport.topRight),
      vecot3FromOffset(inverseMatrix, viewport.bottomRight),
      vecot3FromOffset(inverseMatrix, viewport.bottomLeft),
    );
  }

  Vector3 vecot3FromOffset(Matrix4 inverseMatrix, Offset offset) {
    final vector3 = Vector3(offset.dx, offset.dy, 0);
    return inverseMatrix.transform3(vector3);
  }
}
