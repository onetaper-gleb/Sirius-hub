import 'package:flutter/material.dart';

abstract class ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ChangeTheme extends ThemeEvent {
  final ThemeMode mode;
  ChangeTheme(this.mode);
}
