# Interactive Viewer Plus

<p align="center">
<a href="https://pub.dev/packages/interactive_viewer_plus"><img src="https://img.shields.io/pub/v/interactive_viewer_plus.svg?color=blue" alt="Pub Version"></a>
<a href="https://pub.dev/packages/interactive_viewer_plus"><img src="https://img.shields.io/pub/dm/interactive_viewer_plus.svg?color=blue" alt="Pub Downloads"></a>
<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>

A powerful extension of Flutter's `InteractiveViewer` with advanced programmatic controls. It adds support for rotation, flipping, and precise panning, all manageable via an enhanced controller.

<p align="center">
  <img src="https://raw.githubusercontent.com/burhankhanzada/interactive_viewer_plus/main/preview.gif" alt="Preview" />
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

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  interactive_viewer_plus: ^0.0.4
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

| Method                           | Description                                    |
| -------------------------------- | ---------------------------------------------- |
| `zoom(double factor)`            | Scales the view relative to the current scale. |
| `rotate(double radians)`         | Rotates the view by the given amount.          |
| `flip({bool flipX, bool flipY})` | Flips the view on the specified axes.          |
| `pan(Offset offset)`             | Translates the view by the given offset.       |

## My other packages

- [Go Responsive](https://github.com/burhankhanzada/go_responsive) - A simple but expressive responsive framework.
- [Time Picker Wheel](https://pub.dev/packages/time_picker_wheel) - Time Picker inspired by Oppo Clock.

[![Contributors](https://contrib.rocks/image?repo=burhankhanzada/interactive_viewer_plus)](https://github.com/burhankhanzada/interactive_viewer_plus/graphs/contributors)
