import 'dart:ui';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

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
      math.pow(point.x - closePoint.x, 2) + math.pow(point.y - closePoint.y, 2),
    );
    if (distance < minDistance) {
      minDistance = distance;
      closestOverall = closePoint;
    }
  }
  return closestOverall;
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

/// Transforms a viewport rectangle through the inverse of a transformation
/// matrix.
///
/// This function takes a rectangular viewport and applies the inverse of the
/// given transformation [matrix] to determine what area of the scene
/// corresponds to the current viewport. This is essential for determining
/// which part of the content is currently visible.
///
/// The viewport corners are transformed from screen/widget coordinates
/// back to scene coordinates using the inverse transformation.
///
/// Parameters:
/// - [matrix]: The transformation matrix to invert and apply
/// - [viewport]: The rectangular viewport area in screen coordinates
///
/// Returns a [Quad] representing the viewport area in scene coordinates.
/// The quad corners correspond to: top-left, top-right, bottom-right,
/// bottom-left.
Quad transformViewport(Matrix4 matrix, Rect viewport) {
  // Inverted transformation matrix for converting screen to scene coordinates
  final inverseMatrix = matrix.clone()..invert();
  return Quad.points(
    inverseMatrix.transform3(
      Vector3(viewport.topLeft.dx, viewport.topLeft.dy, 0),
    ),
    inverseMatrix.transform3(
      Vector3(viewport.topRight.dx, viewport.topRight.dy, 0),
    ),
    inverseMatrix.transform3(
      Vector3(viewport.bottomRight.dx, viewport.bottomRight.dy, 0),
    ),
    inverseMatrix.transform3(
      Vector3(viewport.bottomLeft.dx, viewport.bottomLeft.dy, 0),
    ),
  );
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
