import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/bloc/theme/theme_bloc.dart';
import '../../domain/bloc/theme/theme_event.dart';

class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, currentMode) {
        return PopupMenuButton<ThemeMode>(
          tooltip: "Тема оформления",
          icon: Icon(_getIcon(currentMode)),
          onSelected: (mode) {
            context.read<ThemeBloc>().add(ChangeTheme(mode));
          },
          itemBuilder: (context) => [
            _buildMenuItem(
              mode: ThemeMode.system,
              currentMode: currentMode,
              icon: Icons.brightness_auto,
              label: "Системная",
            ),
            _buildMenuItem(
                mode: ThemeMode.light,
                currentMode: currentMode,
                icon: Icons.light_mode,
                label: "Светлая",
            ),
            _buildMenuItem(
                mode: ThemeMode.dark,
                currentMode: currentMode,
                icon: Icons.dark_mode,
                label: "Тёмная",
            ),
          ],
        );
      },
    );
  }

  IconData _getIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  PopupMenuItem<ThemeMode> _buildMenuItem({
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = mode == currentMode;
    return PopupMenuItem<ThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check, size: 18, color: Colors.blue),
        ],
      ),
    );
  }
}
