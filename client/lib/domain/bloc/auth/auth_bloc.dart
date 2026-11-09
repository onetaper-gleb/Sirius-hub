import 'package:bloc/bloc.dart';
import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/data/repository/auth_repository.dart';
import 'package:client/domain/model/model.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class _AuthSessionChanged extends AuthEvent {
  _AuthSessionChanged(this.user);
  final UserModel? user;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpBasicRequested>(_onSignUp);
    on<AuthCompleteRegistrationRequested>(_onCompleteRegistration);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthSubscriptionRequested>(_onSubscription);
    on<AuthGetProfileDataRequested>((event, emit) => _refresh(emit));
    on<_AuthSessionChanged>((event, emit) async {
      if (_busy && event.user != null) return;
      await _refresh(emit);
    });
  }

  final AuthRepository _authRepository;
  int _revision = 0;
  bool _busy = false;

  Exception _exception(Object error) =>
      error is Exception ? error : Exception(error.toString());

  Future<void> _refresh(Emitter<AuthState> emit) async {
    final revision = ++_revision;
    final uid = _authRepository.currentUserId;
    if (uid == null) {
      emit(AuthUnauthenticated());
      return;
    }
    try {
      final pending = await _authRepository.shouldShowRegistrationForUid(uid);
      if (revision != _revision || uid != _authRepository.currentUserId) return;
      if (pending) {
        await RegistrationDraftStorage.setPendingForUid(uid);
        if (revision != _revision || uid != _authRepository.currentUserId)
          return;
        emit(AuthAwaitingProfileCompletion());
        return;
      }
      final profile = await _authRepository.getCurrentProfile();
      if (revision == _revision && uid == _authRepository.currentUserId) {
        emit(AuthAuthenticated(profileModel: profile));
      }
    } catch (error) {
      if (revision == _revision) {
        if (_authRepository.currentUserId == null) {
          emit(AuthUnauthenticated());
        } else if (uid == _authRepository.currentUserId) {
          emit(AuthError(error: _exception(error)));
        }
      }
    }
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    _busy = true;
    ++_revision;
    emit(AuthLoading());
    try {
      await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      await _refresh(emit);
    } catch (error) {
      emit(AuthError(error: _exception(error)));
    } finally {
      _busy = false;
    }
  }

  Future<void> _onSignUp(
    AuthSignUpBasicRequested event,
    Emitter<AuthState> emit,
  ) async {
    _busy = true;
    ++_revision;
    emit(AuthLoading());
    try {
      await _authRepository.signUp(
        email: event.email,
        password: event.password,
      );
      final uid = _authRepository.currentUserId;
      if (uid == null) throw Exception('Не удалось создать аккаунт');
      await RegistrationDraftStorage.setPendingForUid(uid);
      emit(AuthAwaitingProfileCompletion());
    } catch (error) {
      emit(AuthError(error: _exception(error)));
    } finally {
      _busy = false;
    }
  }

  Future<void> _onCompleteRegistration(
    AuthCompleteRegistrationRequested event,
    Emitter<AuthState> emit,
  ) async {
    _busy = true;
    ++_revision;
    emit(AuthLoading());
    try {
      await _authRepository.completeRegistration(event.profile);
      await RegistrationDraftStorage.clearAll();
      await _refresh(emit);
    } catch (error) {
      emit(
        AuthError(
          error: _exception(error),
          awaitingProfile: _authRepository.isSignedIn,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    ++_revision;
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(AuthUnauthenticated());
    } catch (error) {
      emit(AuthError(error: _exception(error)));
    }
  }

  Future<void> _onSubscription(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) => emit.onEach<UserModel?>(
    _authRepository.userStream,
    onData: (user) => add(_AuthSessionChanged(user)),
    onError: (error, stack) => emit(AuthError(error: _exception(error))),
  );
}
