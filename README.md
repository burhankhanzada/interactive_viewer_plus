# Interactive Viewer Plus

A powerful extension of Flutter's `InteractiveViewer` with advanced programmatic controls. It adds support for rotation, flipping, and precise panning, all manageable via an enhanced controller.

<p align="center">
  <img src="./preview.gif" alt="Preview" width="100%" />
</p>

## Features
Interactive Viewer Plus brings the `InteractiveViewer` to the next level with:

- **🔄 Programmatic Rotation**: Effortlessly rotate your content by any angle.
- **↔️ Flipping Support**: Easily flip your content horizontally (X-axis) or vertically (Y-axis).
- **🎯 Precise Panning**: Move the viewport to specific offsets programmatically.
- **🎮 Enhanced Controller**: `InteractiveViewerPlusController` provides more methods than the standard `TransformationController`.
- **⌨️ Keyboard Shortcut Ready**: Built with external triggers in mind, perfect for desktop or tool-heavy apps.
- **🚀 Drop-in Replacement**: Works just like the standard widget but with extra "plus" features.

## Getting started

| Package                  | Version                                                                       |
| -------------------------|-------------------------------------------------------------------------------|
| interactive_viewer_plus  | [![pub package](https://img.shields.io/pub/v/interactive_viewer_plus.svg)](https://pub.dev/packages/interactive_viewer_plus) |

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  interactive_viewer_plus: ^0.0.1
```

## Usage

Using `InteractiveViewerPlus` is straightforward. Just replace your `InteractiveViewer` and use the `InteractiveViewerPlusController` for advanced control.

```dart
import 'package:interactive_viewer_plus/interactive_viewer_plus.dart';

// 1. Initialize the controller
final controller = InteractiveViewerPlusController();

// 2. Use the widget
InteractiveViewerPlus(
  controller: controller,
  minScale: 0.1,
  maxScale: 5.0,
  child: Image.network('https://example.com/large-image.jpg'),
)

// 3. Control it programmatically
controller.zoom(1.2);          // Zoom in 20%
controller.rotate(math.pi / 4); // Rotate 45 degrees
controller.flip(flipX: true);   // Flip horizontally
controller.pan(Offset(10, 0));  // Pan 10 pixels right
```

### Full Programmatic Control

| Method | Description |
| --- | --- |
| `zoom(double factor)` | Scales the view relative to the current scale. |
| `rotate(double radians)`| Rotates the view by the given amount. |
| `flip({bool flipX, bool flipY})` | Flips the view on the specified axes. |
| `pan(Offset offset)` | Translates the view by the given offset. |
| `zoomAt(Offset point, double factor)` | Zooms into a specific point in the viewport. |
| `toScene(Offset viewportPoint)` | Converts viewport coordinates to scene coordinates. |

## Tips
- Set `boundaryMargin: EdgeInsets.all(double.infinity)` if you want to allow panning anywhere without restriction.
- The `InteractiveViewerPlusController` maintains the rotation state in `currentRotation`.

## My other packages
- [Go Responsive](https://github.com/burhankhanzada/go_responsive) - A simple but expressive responsive framework.
- [Time Picker Wheel](https://pub.dev/packages/time_picker_wheel) - Time Picker inspired by Oppo Clock.

[![Contributors](https://contrib.rocks/image?repo=burhankhanzada/interactive_viewer_plus)](https://github.com/burhankhanzada/interactive_viewer_plus/graphs/contributors)

## License
MIT License - see the [LICENSE](LICENSE) file for details.
