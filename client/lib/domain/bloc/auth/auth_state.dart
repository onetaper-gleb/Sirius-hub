import 'package:client/domain/model/profile_model.dart';

// States of authentification for BLoC
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAwaitingProfileCompletion extends AuthState {}

class AuthAuthenticated extends AuthState {
  final ProfileModel profileModel;
  AuthAuthenticated({required this.profileModel});
}

class AuthError extends AuthState {
  final Exception error;
  final bool awaitingProfile;
  AuthError({required this.error, this.awaitingProfile = false});
}
