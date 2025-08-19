import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interactive_viewer_plus/interactive_viewer_plus.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final controller = InteractiveViewerPlusController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.equal): zoomIn,
            const SingleActivator(LogicalKeyboardKey.minus): zoomOut,
            const SingleActivator(LogicalKeyboardKey.comma): rotateLeft,
            const SingleActivator(LogicalKeyboardKey.period): rotateRight,
            const SingleActivator(LogicalKeyboardKey.arrowUp): panUp,
            const SingleActivator(LogicalKeyboardKey.arrowDown): panDown,
            const SingleActivator(LogicalKeyboardKey.arrowLeft): panLeft,
            const SingleActivator(LogicalKeyboardKey.arrowRight): panRight,
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                InteractiveViewerPlus(
                  controller: controller,
                  child: FlutterLogo(size: 1000),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: zoomIn, icon: Icon(Icons.zoom_in)),
                      IconButton(
                        onPressed: zoomOut,
                        icon: Icon(Icons.zoom_out),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: flipHorizontal,
                        icon: Icon(Icons.flip),
                      ),
                      IconButton(
                        onPressed: flipVertical,
                        icon: Transform.rotate(
                          angle: math.pi * 1 / 2,
                          child: Icon(Icons.flip),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void zoomIn() => controller.zoom(1.1);
  void zoomOut() => controller.zoom(0.9);

  void rotateLeft() => controller.rotate(0.1);
  void rotateRight() => controller.rotate(-0.1);

  void flipVertical() => controller.flip(flipY: true);
  void flipHorizontal() => controller.flip(flipX: true);

  void panUp() => controller.pan(const Offset(0, 10));
  void panDown() => controller.pan(const Offset(0, -10));
  void panLeft() => controller.pan(const Offset(10, 0));
  void panRight() => controller.pan(const Offset(-10, 0));
}
