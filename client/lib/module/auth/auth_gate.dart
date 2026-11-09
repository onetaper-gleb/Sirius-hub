import 'package:client/core/dependencies.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:client/domain/bloc/news/news_bloc.dart';
import 'package:client/domain/bloc/forum/forum_controller.dart';
import 'package:client/domain/bloc/forum/forum_event.dart';
import 'package:client/domain/bloc/schedule/schedule_bloc.dart';

import '../app_shell.dart';
import 'login_screen.dart';
import 'registration_profile_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    buildWhen: (previous, current) =>
        current is! AuthLoading || previous is AuthInitial,
    builder: (context, state) {
      if (state is AuthAuthenticated)
        return _AuthenticatedApp(
          key: ValueKey(state.profileModel.userModel.id),
        );
      if (state is AuthAwaitingProfileCompletion ||
          (state is AuthError && state.awaitingProfile)) {
        return const RegistrationProfileScreen();
      }
      if (state is AuthUnauthenticated ||
          (state is AuthError &&
              !context.dependencies.authRepository.isSignedIn)) {
        return const LoginScreen();
      }
      if (state is AuthError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось загрузить профиль'),
                FilledButton(
                  onPressed: () => context.read<AuthBloc>().add(
                    AuthGetProfileDataRequested(),
                  ),
                  child: const Text('Повторить'),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<AuthBloc>().add(AuthSignOutRequested()),
                  child: const Text('Выйти'),
                ),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    },
  );
}

class _AuthenticatedApp extends StatelessWidget {
  const _AuthenticatedApp({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            NewsBloc(newsRepository: context.dependencies.newsRepository),
      ),
      BlocProvider(
        create: (_) =>
            ForumBloc(repository: context.dependencies.forumRepository)
              ..add(ForumLoadRequested()),
      ),
      BlocProvider(
        create: (_) => ScheduleBloc(
          scheduleRepository: context.dependencies.scheduleRepository,
        ),
      ),
    ],
    child: const AppShell(),
  );
}
