import 'dart:ui';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

@visibleForTesting
Vector3 getNearestPointOnLine(Vector3 point, Vector3 l1, Vector3 l2) {
  final lengthSquared =
      math.pow(l2.x - l1.x, 2.0).toDouble() +
      math.pow(l2.y - l1.y, 2.0).toDouble();

  if (lengthSquared == 0) {
    return l1;
  }

  final l1P = point - l1;
  final l1L2 = l2 - l1;
  final fraction = clampDouble(l1P.dot(l1L2) / lengthSquared, 0, 1);
  return l1 + l1L2 * fraction;
}

@visibleForTesting
Quad getAxisAlignedBoundingBox(Quad quad) {
  final double minX = math.min(
    quad.point0.x,
    math.min(quad.point1.x, math.min(quad.point2.x, quad.point3.x)),
  );
  final double minY = math.min(
    quad.point0.y,
    math.min(quad.point1.y, math.min(quad.point2.y, quad.point3.y)),
  );
  final double maxX = math.max(
    quad.point0.x,
    math.max(quad.point1.x, math.max(quad.point2.x, quad.point3.x)),
  );
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

@visibleForTesting
bool pointIsInside(Vector3 point, Quad quad) {
  final aM = point - quad.point0;
  final aB = quad.point1 - quad.point0;
  final aD = quad.point3 - quad.point0;

  final aMAB = aM.dot(aB);
  final aBAB = aB.dot(aB);
  final aMAD = aM.dot(aD);
  final aDAD = aD.dot(aD);

  return 0 <= aMAB && aMAB <= aBAB && 0 <= aMAD && aMAD <= aDAD;
}

@visibleForTesting
Vector3 getNearestPointInside(Vector3 point, Quad quad) {
  if (pointIsInside(point, quad)) {
    return point;
  }

  final closestPoints = <Vector3>[
    getNearestPointOnLine(point, quad.point0, quad.point1),
    getNearestPointOnLine(point, quad.point1, quad.point2),
    getNearestPointOnLine(point, quad.point2, quad.point3),
    getNearestPointOnLine(point, quad.point3, quad.point0),
  ];
  var minDistance = double.infinity;
  late Vector3 closestOverall;
  for (final closePoint in closestPoints) {
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

double getFinalTime(
  double velocity,
  double drag, {
  double effectivelyMotionless = 10,
}) => math.log(effectivelyMotionless / velocity) / math.log(drag / 100);

Offset getMatrixTranslation(Matrix4 matrix) {
  final nextTranslation = matrix.getTranslation();
  return Offset(nextTranslation.x, nextTranslation.y);
}

Quad transformViewport(Matrix4 matrix, Rect viewport) {
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

Quad getAxisAlignedBoundingBoxWithRotation(Rect rect, double rotation) {
  final rotationMatrix = Matrix4.identity()
    ..translateByDouble(rect.size.width / 2, rect.size.height / 2, 0, 1)
    ..rotateZ(rotation)
    ..translateByDouble(-rect.size.width / 2, -rect.size.height / 2, 0, 1);
  final boundariesRotated = Quad.points(
    rotationMatrix.transform3(Vector3(rect.left, rect.top, 0)),
    rotationMatrix.transform3(Vector3(rect.right, rect.top, 0)),
    rotationMatrix.transform3(Vector3(rect.right, rect.bottom, 0)),
    rotationMatrix.transform3(Vector3(rect.left, rect.bottom, 0)),
  );
  return getAxisAlignedBoundingBox(boundariesRotated);
}

Offset exceedsBy(Quad boundary, Quad viewport) {
  final viewportPoints = <Vector3>[
    viewport.point0,
    viewport.point1,
    viewport.point2,
    viewport.point3,
  ];
  var largestExcess = Offset.zero;
  for (final point in viewportPoints) {
    final pointInside = getNearestPointInside(point, boundary);
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

Offset round(Offset offset) => Offset(
  double.parse(offset.dx.toStringAsFixed(9)),
  double.parse(offset.dy.toStringAsFixed(9)),
);

Offset alignAxis(Offset offset, Axis axis) => switch (axis) {
  Axis.horizontal => Offset(offset.dx, 0),
  Axis.vertical => Offset(0, offset.dy),
};

Axis? getPanAxis(Offset point1, Offset point2) {
  if (point1 == point2) {
    return null;
  }
  final x = point2.dx - point1.dx;
  final y = point2.dy - point1.dy;
  return x.abs() > y.abs() ? Axis.horizontal : Axis.vertical;
}
