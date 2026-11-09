import 'dart:async';

import 'package:client/data/repository/auth_repository.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/model/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements AuthRepository {}

void main() {
  test('a late profile lookup cannot restore a signed-out session', () async {
    final repo = MockRepository();
    final changes = StreamController<UserModel?>();
    final pending = Completer<bool>();
    String? uid = 'old-user';
    when(() => repo.currentUserId).thenAnswer((_) => uid);
    when(() => repo.userStream).thenAnswer((_) => changes.stream);
    when(
      () => repo.shouldShowRegistrationForUid('old-user'),
    ).thenAnswer((_) => pending.future);
    when(() => repo.signOut()).thenAnswer((_) async {
      uid = null;
    });
    final bloc = AuthBloc(authRepository: repo)
      ..add(AuthSubscriptionRequested());
    changes.add(const UserModel(id: 'old-user', email: 'a@b.co'));
    await Future<void>.delayed(Duration.zero);
    final signedOut = bloc.stream.firstWhere(
      (state) => state is AuthUnauthenticated,
    );
    bloc.add(AuthSignOutRequested());
    await signedOut;
    pending.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<AuthUnauthenticated>());
    verifyNever(() => repo.getCurrentProfile());
    await changes.close();
    await bloc.close();
  });

  test(
    'non-Exception profile failures become an error state instead of a cast failure',
    () async {
      final repo = MockRepository();
      when(() => repo.currentUserId).thenReturn('user');
      when(
        () => repo.shouldShowRegistrationForUid('user'),
      ).thenThrow(StateError('invalid response'));
      final bloc = AuthBloc(authRepository: repo);
      final error = bloc.stream.firstWhere((s) => s is AuthError);
      bloc.add(AuthGetProfileDataRequested());
      expect(await error, isA<AuthError>());
      await bloc.close();
    },
  );
}
