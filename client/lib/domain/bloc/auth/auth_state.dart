import 'package:client/domain/model/model.dart';
import 'package:client/domain/model/profile_model.dart';

// States of authentification for BLoC
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

/// Firebase-аккаунт создан, ждём экран профиля и вызов бэкенда.
class AuthAwaitingProfileCompletion extends AuthState {}

class AuthAuthenticated extends AuthState {
  final ProfileModel profileModel;
  AuthAuthenticated({required this.profileModel});
}

class AuthError extends AuthState {
  final Exception error;
  AuthError({required this.error});
}
