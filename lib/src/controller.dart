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

  void zoomAt(Offset viewportLocal, double scaleChange) {
    final reference = toScene(viewportLocal);
    value = matrixScale(value, scaleChange);
    final after = toScene(viewportLocal);
    value = matrixTranslate(value, after - reference);
  }

  void panFromLocalTo(Offset fromLocal, Offset toLocal) {
    final a = toScene(fromLocal);
    final b = toScene(toLocal);
    value = matrixTranslate(value, b - a);
  }

  void flip({bool flipX = false, bool flipY = false}) {
    value = matrixFlip(
      value,
      flipX: flipX,
      flipY: flipY,
      focalPoint: viewport.center,
    );
  }

  void rotate(double deltaRotation) {
    value = matrixRotate(value, deltaRotation, viewport.center);
    currentRotation += deltaRotation;
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
    final dx = focalPointScene.dx;
    final dy = focalPointScene.dy;

    return matrix.clone()
      ..translateByDouble(dx, dy, 0, 1)
      ..rotateZ(-rotation)
      ..translateByDouble(-dx, -dy, 0, 1);
  }

  Matrix4 matrixScale(Matrix4 matrix, double scale) {
    if (scale == 1.0) {
      return matrix.clone();
    }
    assert(scale != 0.0);

    final currentScale = value.getMaxScaleOnAxis();
    final viewportWidth = viewport.width;
    final viewportHeight = viewport.height;
    final boundaryWidth = boundaryRect.width;
    final boundaryHeight = boundaryRect.height;

    final minRequiredScale = math.max(
      viewportWidth / boundaryWidth,
      viewportHeight / boundaryHeight,
    );

    final desiredTotalScale = currentScale * scale;

    final totalScale = math.max(desiredTotalScale, minRequiredScale);

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
    final focalPointScene = toScene(focalPoint);
    final dx = focalPointScene.dx;
    final dy = focalPointScene.dy;

    final candidate = matrix.clone()
      ..translateByDouble(dx, dy, 0, 1)
      ..rotateZ(currentRotation)
      ..scaleByDouble(sx, sy, 1, 1)
      ..rotateZ(-currentRotation)
      ..translateByDouble(-dx, -dy, 0, 1);

    return _correctForBoundary(original: matrix, candidate: candidate);
  }

  Matrix4 matrixTranslate(Matrix4 matrix, Offset translation) {
    if (translation == Offset.zero) {
      return matrix.clone();
    }

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

    final candidate = matrix.clone()
      ..translateByDouble(alignedTranslation.dx, alignedTranslation.dy, 0, 1);

    return _correctForBoundary(original: matrix, candidate: candidate);
  }

  Matrix4 _correctForBoundary({
    required Matrix4 original,
    required Matrix4 candidate,
  }) {
    if (boundaryRect.isInfinite) {
      return candidate;
    }

    final nextViewport = transformViewport(candidate, viewport);

    final boundariesAabbQuad = getAxisAlignedBoundingBoxWithRotation(
      boundaryRect,
      currentRotation,
    );

    final offendingDistance = exceedsBy(boundariesAabbQuad, nextViewport);

    if (offendingDistance == Offset.zero) {
      return candidate;
    }

    final nextTotalTranslation = getMatrixTranslation(candidate);

    final offendingDx = offendingDistance.dx;
    final offendingDy = offendingDistance.dy;

    final currentScale = candidate.getMaxScaleOnAxis();

    final correctedTotalTranslation = Offset(
      nextTotalTranslation.dx - offendingDx * currentScale,
      nextTotalTranslation.dy - offendingDy * currentScale,
    );

    final correctedMatrix = candidate.clone()
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

    final correctedOffendingDx = offendingCorrectedDistance.dx;
    final correctedOffendingDy = offendingCorrectedDistance.dy;

    if (correctedOffendingDx != 0.0 && correctedOffendingDy != 0.0) {
      return original;
    }

    final originalTranslation = getMatrixTranslation(original);
    final originalDx = originalTranslation.dx;
    final originalDy = originalTranslation.dy;

    final correctedDx = correctedTotalTranslation.dx;
    final correctedDy = correctedTotalTranslation.dy;

    final finalTranslation = Offset(
      correctedOffendingDx == 0.0 ? correctedDx : originalDx,
      correctedOffendingDy == 0.0 ? correctedDy : originalDy,
    );

    return candidate.clone()
      ..setTranslation(Vector3(finalTranslation.dx, finalTranslation.dy, 0));
  }
}
