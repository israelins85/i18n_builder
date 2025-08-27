import 'package:example/main.i18n.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            children: [
              Text('Hello New World!'.i18n),
              Text(
                'Long text to test the translation at breaking lines. Keep going to get more lines or mine not!'
                    .i18n,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
