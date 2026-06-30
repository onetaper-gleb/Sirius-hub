import 'package:client/core/dependencies.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_shell.dart';
import 'login_screen.dart';
import 'registration_profile_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const AppShell();
            }
            if (state is AuthAwaitingProfileCompletion) {
              return const RegistrationProfileScreen();
            }
            return FutureBuilder<bool>(
              future: context.dependencies.authRepository
                  .shouldShowRegistrationForUid(firebaseUser.uid),
              builder: (context, pendingSnap) {
                if (pendingSnap.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (pendingSnap.data == true) {
                  return const RegistrationProfileScreen();
                }
                return const AppShell();
              },
            );
          },
        );
      },
    );
  }
}
