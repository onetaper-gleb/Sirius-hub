import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  static const _prefsKey = 'theme_mode';

  ThemeBloc() : super(ThemeMode.system) {
    on<LoadTheme>(_onLoad);
    on<ChangeTheme>(_onChange);
  }

  Future<void> _onLoad(LoadTheme event, Emitter<ThemeMode> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    switch (saved) {
      case 'light':
        emit(ThemeMode.light);
        break;
      case 'dark':
        emit(ThemeMode.dark);
        break;
      default:
        emit(ThemeMode.system);
    }
  }

  Future<void> _onChange(ChangeTheme event, Emitter<ThemeMode> emit) async {
    emit(event.mode);

    final prefs = await SharedPreferences.getInstance();
    String value;
    switch (event.mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      default:
        value = 'system';
    }
    await prefs.setString(_prefsKey, value);
  }
}
