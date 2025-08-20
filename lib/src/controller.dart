import 'dart:ui';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:flutter/widgets.dart';

import 'helper_methods.dart';

class InteractiveViewerPlusController extends ValueNotifier<Matrix4> {
  double currentRotation = 0;

  late double minScale;

  late double maxScale;

  Axis? currentAxis;

  late PanAxis panAxis;

  late Rect viewport;

  late Rect boundaryRect;

  InteractiveViewerPlusController([Matrix4? value])
    : super(value ?? Matrix4.identity());

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

  void pan(Offset offset) {
    value = matrixTranslate(value, offset);
  }

  void zoom(double scale) {
    value = matrixScale(value, scale);
  }

  void flip({bool flipX = false, bool flipY = false}) {
    value = matrixFlip(
      value,
      flipX: flipX,
      flipY: flipY,
      focalPoint: viewport.center,
    );
  }

  void rotate(double rotation) {
    final focalPointScene = toScene(viewport.center);
    value = matrixRotate(value, rotation, focalPointScene);
    currentRotation = rotation;
  }

  Offset toScene(Offset viewportPoint) {
    final inverseMatrix = Matrix4.inverted(value);
    final untransformed = inverseMatrix.transform3(
      Vector3(viewportPoint.dx, viewportPoint.dy, 0),
    );
    return Offset(untransformed.x, untransformed.y);
  }

  Matrix4 matrixRotate(Matrix4 matrix, double rotation, Offset focalPoint) {
    if (rotation == 0) {
      return matrix.clone();
    }
    final focalPointScene = toScene(focalPoint);
    return matrix.clone()
      ..translateByDouble(focalPointScene.dx, focalPointScene.dy, 0, 1)
      ..rotateZ(-rotation)
      ..translateByDouble(-focalPointScene.dx, -focalPointScene.dy, 0, 1);
  }

  Matrix4 matrixScale(Matrix4 matrix, double scale) {
    if (scale == 1.0) {
      return matrix.clone();
    }
    assert(scale != 0.0);

    final currentScale = value.getMaxScaleOnAxis();
    final double totalScale = math.max(
      currentScale * scale,

      math.max(
        viewport.width / boundaryRect.width,
        viewport.height / boundaryRect.height,
      ),
    );
    final clampedTotalScale = clampDouble(totalScale, minScale, maxScale);
    final clampedScale = clampedTotalScale / currentScale;
    return matrix.clone()
      ..scaleByDouble(clampedScale, clampedScale, clampedScale, 1);
  }

  Matrix4 matrixFlip(
    Matrix4 matrix, {
    required bool flipX,
    required bool flipY,
    required Offset focalPoint,
  }) {
    if (!flipX && !flipY) {
      return matrix.clone();
    }

    final sx = flipX ? -1.0 : 1.0;
    final sy = flipY ? -1.0 : 1.0;

    // Convert viewport-space focal point to scene-space
    final focalPointScene = toScene(focalPoint);

    // Apply flip around the focal point
    final nextMatrix = matrix.clone()
      ..translateByDouble(focalPointScene.dx, focalPointScene.dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-focalPointScene.dx, -focalPointScene.dy, 0, 1);

    // No boundary? We're done.
    if (boundaryRect.isInfinite) {
      return nextMatrix;
    }

    // Boundary handling: same pattern as matrixTranslate
    final nextViewport = transformViewport(nextMatrix, viewport);
    final boundariesAabbQuad = getAxisAlignedBoundingBoxWithRotation(
      boundaryRect,
      currentRotation,
    );

    final offendingDistance = exceedsBy(boundariesAabbQuad, nextViewport);
    if (offendingDistance == Offset.zero) {
      return nextMatrix;
    }

    final nextTotalTranslation = getMatrixTranslation(nextMatrix);
    final currentScale = nextMatrix.getMaxScaleOnAxis();
    final correctedTotalTranslation = Offset(
      nextTotalTranslation.dx - offendingDistance.dx * currentScale,
      nextTotalTranslation.dy - offendingDistance.dy * currentScale,
    );

    final correctedMatrix = nextMatrix.clone()
      ..setTranslation(
        Vector3(correctedTotalTranslation.dx, correctedTotalTranslation.dy, 0),
      );

    final correctedViewport = transformViewport(correctedMatrix, viewport);
    final offendingCorrectedDistance = exceedsBy(
      boundariesAabbQuad,
      correctedViewport,
    );

    if (offendingCorrectedDistance == Offset.zero) {
      return correctedMatrix;
    }

    // If both axes still offend, abort flip and keep the original matrix
    if (offendingCorrectedDistance.dx != 0.0 &&
        offendingCorrectedDistance.dy != 0.0) {
      return matrix.clone();
    }

    // Allow only the axis that doesn't offend
    final unidirectionalCorrectedTotalTranslation = Offset(
      offendingCorrectedDistance.dx == 0.0 ? correctedTotalTranslation.dx : 0.0,
      offendingCorrectedDistance.dy == 0.0 ? correctedTotalTranslation.dy : 0.0,
    );

    return nextMatrix.clone()..setTranslation(
      Vector3(
        unidirectionalCorrectedTotalTranslation.dx,
        unidirectionalCorrectedTotalTranslation.dy,
        0,
      ),
    );
  }

  Matrix4 matrixTranslate(Matrix4 matrix, Offset translation) {
    if (translation == Offset.zero) {
      return matrix.clone();
    }

    final Offset alignedTranslation;

    if (currentAxis != null) {
      alignedTranslation = switch (panAxis) {
        PanAxis.horizontal => alignAxis(translation, Axis.horizontal),
        PanAxis.vertical => alignAxis(translation, Axis.vertical),
        PanAxis.aligned => alignAxis(translation, currentAxis!),
        PanAxis.free => translation,
      };
    } else {
      alignedTranslation = translation;
    }

    final nextMatrix = matrix.clone()
      ..translateByDouble(alignedTranslation.dx, alignedTranslation.dy, 0, 1);

    final nextViewport = transformViewport(nextMatrix, viewport);

    if (boundaryRect.isInfinite) {
      return nextMatrix;
    }

    final boundariesAabbQuad = getAxisAlignedBoundingBoxWithRotation(
      boundaryRect,
      currentRotation,
    );

    final offendingDistance = exceedsBy(boundariesAabbQuad, nextViewport);
    if (offendingDistance == Offset.zero) {
      return nextMatrix;
    }

    final nextTotalTranslation = getMatrixTranslation(nextMatrix);
    final currentScale = matrix.getMaxScaleOnAxis();
    final correctedTotalTranslation = Offset(
      nextTotalTranslation.dx - offendingDistance.dx * currentScale,
      nextTotalTranslation.dy - offendingDistance.dy * currentScale,
    );

    final correctedMatrix = matrix.clone()
      ..setTranslation(
        Vector3(correctedTotalTranslation.dx, correctedTotalTranslation.dy, 0),
      );

    final correctedViewport = transformViewport(correctedMatrix, viewport);

    final offendingCorrectedDistance = exceedsBy(
      boundariesAabbQuad,
      correctedViewport,
    );

    if (offendingCorrectedDistance == Offset.zero) {
      return correctedMatrix;
    }

    if (offendingCorrectedDistance.dx != 0.0 &&
        offendingCorrectedDistance.dy != 0.0) {
      return matrix.clone();
    }

    final unidirectionalCorrectedTotalTranslation = Offset(
      offendingCorrectedDistance.dx == 0.0 ? correctedTotalTranslation.dx : 0.0,
      offendingCorrectedDistance.dy == 0.0 ? correctedTotalTranslation.dy : 0.0,
    );

    return matrix.clone()..setTranslation(
      Vector3(
        unidirectionalCorrectedTotalTranslation.dx,
        unidirectionalCorrectedTotalTranslation.dy,
        0,
      ),
    );
  }
}
