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
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): panUp,
          const SingleActivator(LogicalKeyboardKey.arrowDown): panDown,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): panLeft,
          const SingleActivator(LogicalKeyboardKey.arrowRight): panRight,
        },
        child: Focus(
          autofocus: true,
          child: InteractiveViewerPlus(
            controller: controller,
            child: FlutterLogo(size: 1000),
          ),
        ),
      ),
    );
  }

  void panUp() => controller.pan(const Offset(0, 10));
  void panDown() => controller.pan(const Offset(0, -10));
  void panLeft() => controller.pan(const Offset(10, 0));
  void panRight() => controller.pan(const Offset(-10, 0));
}
