import 'package:flutter/material.dart';
import 'ui/eq_screen.dart';

void main() {
  runApp(LuminaProApp());
}

class LuminaProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
      ),
      home: EqScreen(),
    );
  }
}