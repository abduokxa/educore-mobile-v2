import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'features/errors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  startErrorReporting();
  runApp(const EducoreApp());
}
