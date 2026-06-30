// Events of authentification for BLoC

import 'package:client/domain/model/model.dart';

abstract class AuthEvent {}

class AuthSignUpBasicRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignUpBasicRequested({required this.email, required this.password});
}

class AuthCompleteRegistrationRequested extends AuthEvent {
  final RegistrationProfileData profile;
  AuthCompleteRegistrationRequested({required this.profile});
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignInRequested({required this.email, required this.password});
}

class AuthSignOutRequested extends AuthEvent {}

class AuthSubscriptionRequested extends AuthEvent {}

class AuthGetProfileDataRequested extends AuthEvent {}
