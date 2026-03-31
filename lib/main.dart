import 'package:flutter/material.dart';
import 'package:tgsorter/app/app.dart';
import 'package:tgsorter/app/bindings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const TgSorterApp());
}
