import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:certifeasy/app_widget.dart';
import 'package:certifeasy/app_module.dart';

void main() {
  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}
