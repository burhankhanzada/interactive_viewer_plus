import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

class TransformationController extends ValueNotifier<Matrix4> {
  TransformationController([Matrix4? value])
    : super(value ?? Matrix4.identity());

  Offset toScene(Offset viewportPoint) {
    final Matrix4 inverseMatrix = Matrix4.inverted(value);
    final Vector3 untransformed = inverseMatrix.transform3(
      Vector3(viewportPoint.dx, viewportPoint.dy, 0),
    );
    return Offset(untransformed.x, untransformed.y);
  }
}
