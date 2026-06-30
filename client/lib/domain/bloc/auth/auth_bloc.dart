// Models imports
import 'package:client/domain/model/model.dart';
import 'package:client/domain/model/profile_model.dart';

import 'auth_state.dart';
import 'auth_event.dart';

// Packages imports
import 'package:bloc/bloc.dart';

// Repos imports
import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/data/repository/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpBasicRequested>(_onSignUpBasic);
    on<AuthCompleteRegistrationRequested>(_onCompleteRegistration);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthSubscriptionRequested>(_onSubscriptionRequest);
    on<AuthGetProfileDataRequested>(_getProfileData);
  }

  Future<void> _getProfileData(
    AuthGetProfileDataRequested event,
    Emitter<AuthState> emit,
  ) async {
    late final usData;
    if (state is AuthAuthenticated) {
      usData = (state as AuthAuthenticated).profileModel;
    } else {
      emit(AuthUnauthenticated());
      return;
    }
    emit(AuthLoading());
    try {
      final RegistrationProfileData regProf = await _authRepository
          .getProfileData();
      final user = ProfileModel(
        registrationProfileData: regProf,
        userModel: usData.userModel,
      );
      emit(AuthAuthenticated(profileModel: user));
    } catch (e) {
      print(e.toString());
      emit(AuthError(error: e as Exception));
    }
  }

  // Authentication handlers
  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final ProfileModel user = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(profileModel: user));
    } catch (e) {
      print(e.toString());
      emit(AuthError(error: e as Exception));
    }
  }

  Future<void> _onSignUpBasic(
    AuthSignUpBasicRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signUpFirebaseOnly(
        email: event.email,
        password: event.password,
      );
      final uid = _authRepository.currentFirebaseUid;
      if (uid == null) {
        emit(AuthError(error: Exception('Не удалось создать аккаунт')));
        return;
      }
      await RegistrationDraftStorage.setPendingForUid(uid);
      emit(AuthAwaitingProfileCompletion());
    } catch (e) {
      print(e.toString());
      emit(AuthError(error: e as Exception));
    }
  }

  Future<void> _onCompleteRegistration(
    AuthCompleteRegistrationRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final UserModel user = await _authRepository.completeRegistration(
        event.profile,
      );
      await RegistrationDraftStorage.clearAll();
      final authProfile = ProfileModel(
        registrationProfileData: event.profile,
        userModel: user,
      );
      emit(AuthAuthenticated(profileModel: authProfile));
    } catch (e) {
      print(e.toString());
      if (!_authRepository.isFirebaseSignedIn) {
        await RegistrationDraftStorage.clearAll();
      }
      emit(AuthError(error: e as Exception));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      print(e.toString());
      emit(AuthError(error: e as Exception));
    }
  }

  Future<void> _onSubscriptionRequest(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    await emit.forEach<AuthState>(
      _authRepository.userStream.asyncMap((user) async {
        if (user == null) return AuthUnauthenticated();
        final needsProfileCompletion = await _authRepository
            .shouldShowRegistrationForUid(user.id);
        if (needsProfileCompletion) return AuthAwaitingProfileCompletion();
        final us = await _authRepository.getProfileData();
        return AuthAuthenticated(
          profileModel: ProfileModel(
            registrationProfileData: us,
            userModel: user,
          ),
        );
      }),
      onData: (state) => state,
      onError: (e, stackTrace) => AuthError(error: e as Exception),
    );
  }
}
