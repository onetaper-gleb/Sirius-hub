import 'package:client/domain/model/model.dart';

// States of authentification for BLoC
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAwaitingProfileCompletion extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated({required this.user});
}

class AuthError extends AuthState {
  final Exception error;
  AuthError({required this.error});
}
