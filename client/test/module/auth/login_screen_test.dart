import 'dart:async';

import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/module/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAuthState extends Fake implements AuthState {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(FakeAuthState());
  });

  late MockAuthBloc authBloc;
  late StreamController<AuthState> stateController;

  setUp(() {
    authBloc = MockAuthBloc();
    stateController = StreamController<AuthState>.broadcast();

    when(() => authBloc.state).thenReturn(AuthInitial());
    when(() => authBloc.stream).thenAnswer((_) => stateController.stream);
    when(() => authBloc.add(any())).thenReturn(null);
    when(() => authBloc.close()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await stateController.close();
  });

  Widget makeWidget() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const LoginScreen(),
      ),
    );
  }

  testWidgets('shows validation when fields are empty', (tester) async {
    await tester.pumpWidget(makeWidget());
    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Заполни все поля'), findsOneWidget);
    verifyNever(() => authBloc.add(any()));
  });

  testWidgets('shows mismatch error on sign up', (tester) async {
    await tester.pumpWidget(makeWidget());

    await tester.tap(find.text('Нет аккаунта? Зарегистрируйся'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'mail@test.dev');
    await tester.enterText(find.byType(TextField).at(1), 'pass1');
    await tester.enterText(find.byType(TextField).at(2), 'pass2');

    await tester.tap(find.text('Продолжить'));
    await tester.pump();

    expect(find.text('Пароли не сопадают'), findsOneWidget);
    verifyNever(() => authBloc.add(any()));
  });

  testWidgets('dispatches sign-in event for valid credentials', (tester) async {
    await tester.pumpWidget(makeWidget());

    await tester.enterText(find.byType(TextField).at(0), 'mail@test.dev');
    await tester.enterText(find.byType(TextField).at(1), 'password123');

    await tester.tap(find.text('Войти'));
    await tester.pump();

    verify(
      () => authBloc.add(
        any(
          that: isA<AuthSignInRequested>()
              .having((event) => event.email, 'email', 'mail@test.dev')
              .having((event) => event.password, 'password', 'password123'),
        ),
      ),
    ).called(1);
  });

  testWidgets('clears repeated password when switching back to login', (
    tester,
  ) async {
    await tester.pumpWidget(makeWidget());

    await tester.tap(find.text('Нет аккаунта? Зарегистрируйся'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), 'repeat-pass');

    await tester.tap(find.text('Уже есть аккаунт? Войди'));
    await tester.pump();
    await tester.tap(find.text('Нет аккаунта? Зарегистрируйся'));
    await tester.pump();

    final repeatField = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(repeatField.controller!.text, isEmpty);
  });
}
