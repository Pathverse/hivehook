import 'package:flutter/material.dart';
import '../main.dart';

typedef LogCallback = void Function(String message, {LogLevel level});

abstract class Scenario {
  String get name;
  String get description;
  IconData get icon;
  List<String> get tags;

  Future<void> run(LogCallback log);
}
