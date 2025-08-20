import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interactive_viewer_plus/src/helper_methods.dart';
import 'dart:math' as math;

void main() {
  group('alignAxis function tests', () {
    test('alignAxis with no rotation should work like before', () {
      const offset = Offset(10.0, 5.0);
      
      // Test horizontal alignment with no rotation
      final horizontalResult = alignAxis(offset, Axis.horizontal, 0);
      expect(horizontalResult.dx, equals(10.0));
      expect(horizontalResult.dy, equals(0.0));
      
      // Test vertical alignment with no rotation
      final verticalResult = alignAxis(offset, Axis.vertical, 0);
      expect(verticalResult.dx, equals(0.0));
      expect(verticalResult.dy, equals(5.0));
    });
    
    test('alignAxis with 90-degree rotation should work correctly', () {
      // Test case: movement that aligns with rotated horizontal axis
      const offset = Offset(0.0, 10.0); // Vertical movement in screen space
      const rotation = math.pi / 2; // 90 degrees clockwise
      
      // When object is rotated 90° clockwise:
      // - The object's horizontal axis points in the (0, 1) direction (screen vertical)
      // - So a vertical screen movement (0, 10) should align perfectly with horizontal object axis
      final horizontalResult = alignAxis(offset, Axis.horizontal, rotation);
      
      print('horizontalResult with (0,10) and 90° rotation: $horizontalResult');
      
      // Should be approximately (0, 10) because the vertical movement aligns with rotated horizontal axis
      expect(horizontalResult.dx, closeTo(0.0, 0.01));
      expect(horizontalResult.dy, closeTo(10.0, 0.01));
      
      // Test case: movement perpendicular to rotated horizontal axis
      const perpendicularOffset = Offset(10.0, 0.0); // Horizontal movement in screen space
      final perpendicularResult = alignAxis(perpendicularOffset, Axis.horizontal, rotation);
      
      print('horizontalResult with (10,0) and 90° rotation: $perpendicularResult');
      
      // Should be (0, 0) because horizontal screen movement is perpendicular to rotated horizontal axis
      expect(perpendicularResult.dx, closeTo(0.0, 0.01));
      expect(perpendicularResult.dy, closeTo(0.0, 0.01));
    });
    
    test('alignAxis with 45-degree rotation should work correctly', () {
      const offset = Offset(10.0, 0.0); // Pure horizontal movement
      const rotation = math.pi / 4; // 45 degrees
      
      final result = alignAxis(offset, Axis.horizontal, rotation);
      
      // With 45° rotation, horizontal constraint should result in diagonal movement
      // The exact values depend on the mathematical implementation
      print('45-degree rotation result: $result');
      
      // The result should have both x and y components
      expect(result.dx.abs() > 0, isTrue);
      expect(result.dy.abs() > 0, isTrue);
    });
    
    test('alignAxis should preserve movement magnitude in the allowed direction', () {
      const offset = Offset(7.0, 7.0); // Diagonal movement
      const rotation = 0.0; // No rotation
      
      final horizontalResult = alignAxis(offset, Axis.horizontal, rotation);
      final verticalResult = alignAxis(offset, Axis.vertical, rotation);
      
      // Without rotation, should just zero out one component
      expect(horizontalResult, equals(const Offset(7.0, 0.0)));
      expect(verticalResult, equals(const Offset(0.0, 7.0)));
    });
  });
}
