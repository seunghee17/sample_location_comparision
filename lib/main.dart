
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sample_location_comparision/legacy/sample_location.dart';
import 'package:sample_location_comparision/presentation/home_page.dart';

import 'data/locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FSV Reliable Location',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

