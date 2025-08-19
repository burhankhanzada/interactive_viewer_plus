import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:interactive_viewer_plus/src/helper_methods.dart';

class InteractiveViewerPlusController extends ValueNotifier<Matrix4> {
  InteractiveViewerPlusController([Matrix4? value])
    : super(value ?? Matrix4.identity());

  double currentRotation = 0.0;

  late double minScale;
  late double maxScale;

  Axis? currentAxis;
  late PanAxis panAxis;

  late Rect viewport;
  late Rect boundaryRect;

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

  void rotate(double rotation) {
    final Offset focalPointScene = toScene(viewport.center);
    value = matrixRotate(value, rotation, focalPointScene);
    currentRotation = rotation;
  }

  Offset toScene(Offset viewportPoint) {
    final Matrix4 inverseMatrix = Matrix4.inverted(value);
    final Vector3 untransformed = inverseMatrix.transform3(
      Vector3(viewportPoint.dx, viewportPoint.dy, 0),
    );
    return Offset(untransformed.x, untransformed.y);
  }

  Matrix4 matrixRotate(Matrix4 matrix, double rotation, Offset focalPoint) {
    if (rotation == 0) {
      return matrix.clone();
    }
    final Offset focalPointScene = toScene(focalPoint);
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

    final double currentScale = value.getMaxScaleOnAxis();
    final double totalScale = math.max(
      currentScale * scale,

      math.max(
        viewport.width / boundaryRect.width,
        viewport.height / boundaryRect.height,
      ),
    );
    final double clampedTotalScale = clampDouble(
      totalScale,
      minScale,
      maxScale,
    );
    final double clampedScale = clampedTotalScale / currentScale;
    return matrix.clone()
      ..scaleByDouble(clampedScale, clampedScale, clampedScale, 1);
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

    final Matrix4 nextMatrix = matrix.clone()
      ..translateByDouble(alignedTranslation.dx, alignedTranslation.dy, 0, 1);

    final Quad nextViewport = transformViewport(nextMatrix, viewport);

    if (boundaryRect.isInfinite) {
      return nextMatrix;
    }

    final Quad boundariesAabbQuad = getAxisAlignedBoundingBoxWithRotation(
      boundaryRect,
      currentRotation,
    );

    final Offset offendingDistance = exceedsBy(
      boundariesAabbQuad,
      nextViewport,
    );
    if (offendingDistance == Offset.zero) {
      return nextMatrix;
    }

    final Offset nextTotalTranslation = getMatrixTranslation(nextMatrix);
    final double currentScale = matrix.getMaxScaleOnAxis();
    final Offset correctedTotalTranslation = Offset(
      nextTotalTranslation.dx - offendingDistance.dx * currentScale,
      nextTotalTranslation.dy - offendingDistance.dy * currentScale,
    );

    final Matrix4 correctedMatrix = matrix.clone()
      ..setTranslation(
        Vector3(
          correctedTotalTranslation.dx,
          correctedTotalTranslation.dy,
          0.0,
        ),
      );

    final Quad correctedViewport = transformViewport(correctedMatrix, viewport);

    final Offset offendingCorrectedDistance = exceedsBy(
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

    final Offset unidirectionalCorrectedTotalTranslation = Offset(
      offendingCorrectedDistance.dx == 0.0 ? correctedTotalTranslation.dx : 0.0,
      offendingCorrectedDistance.dy == 0.0 ? correctedTotalTranslation.dy : 0.0,
    );

    return matrix.clone()..setTranslation(
      Vector3(
        unidirectionalCorrectedTotalTranslation.dx,
        unidirectionalCorrectedTotalTranslation.dy,
        0.0,
      ),
    );
  }
}
