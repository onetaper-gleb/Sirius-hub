import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/model/user_models/user_role.dart';

class AdminFab extends StatelessWidget {
  final VoidCallback onPressed;
  final ValueListenable<bool>? notifier;
  final String heroTag;

  const AdminFab({
    super.key,
    required this.onPressed,
    this.notifier,
    this.heroTag = 'admin_fab',
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select((AuthBloc bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated &&
          state.profileModel.userModel.role == UserRole.council;
    });

    if (!isAdmin) return const SizedBox.shrink();

    final fab = FloatingActionButton(
      onPressed: onPressed,
      heroTag: heroTag,
      child: const Icon(Icons.add),
    );

    if (notifier == null) return fab;

    return ValueListenableBuilder<bool>(
      valueListenable: notifier!,
      builder: (context, isVisible, child) {
        return isVisible ? fab : const SizedBox.shrink();
      },
    );
  }
}
