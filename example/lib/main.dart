import 'package:flutter/material.dart';
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: InteractiveViewerPlus());
  }
}
