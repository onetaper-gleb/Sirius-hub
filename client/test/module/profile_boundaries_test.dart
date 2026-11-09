import 'package:client/core/dependencies.dart';
import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/data/repository/repository.dart';
import 'package:client/data/source/source.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_event.dart';
import 'package:client/domain/bloc/theme/theme_bloc.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/module/auth/auth_gate.dart';
import 'package:client/module/auth/registration_profile_screen.dart';
import 'package:client/module/profile/profile_edit_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/json_api.dart';
import 'account_routes_test.dart'
    show NewsRepoMock, ScheduleRepoMock, ForumRepoMock, TopicRepoMock;

class ProfileSource extends Mock implements AuthDataSource {}

class ProfileHarness {
  final source = ProfileSource();
  final news = NewsRepoMock();
  final forum = ForumRepoMock();
  final theme = ThemeBloc();
  final profile = <String, dynamic>{
    'id': 'user',
    'display_name': 'Alice',
    'avatar_emoji': '😀',
    'role': 'student',
  };
  late final JsonApi api;
  late final AuthRepository repository;
  late final AuthBloc auth;

  ProfileHarness() {
    when(() => source.currentUser).thenReturn(const AuthUser(uid: 'user'));
    when(() => source.needsBackendInit).thenReturn(false);
    when(
      () => source.getToken(forceRefresh: true),
    ).thenAnswer((_) async => 'token');
    when(() => source.setUserDisplayName(any())).thenAnswer((_) async {});
    when(() => news.getAllNews()).thenAnswer((_) async => []);
    when(() => forum.getTopics()).thenAnswer((_) async => []);
    api = JsonApi((request, body) {
      if (request.method == 'PUT' || request.method == 'PATCH') {
        profile.addAll(body!);
      }
      return profile;
    });
    repository = AuthRepository(
      authDataSource: source,
      dio: Dio(BaseOptions(baseUrl: 'https://example.test/'))
        ..httpClientAdapter = api,
    );
    auth = AuthBloc(authRepository: repository);
  }

  List<Map<String, dynamic>> get updates => [
    for (final (request, body) in api.requests)
      if (request.path == 'profile/update') body!,
  ];

  Future<void> pump(
    WidgetTester tester,
    bool registration, {
    String avatar = '😀',
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    profile['avatar_emoji'] = avatar;
    if (registration) {
      await RegistrationDraftStorage.setPendingForUid('user');
      await RegistrationDraftStorage.saveDraft(
        RegistrationProfileData(displayName: 'Alice', avatarEmoji: avatar),
      );
    }
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: Dependencies(
          authRepository: repository,
          newsRepository: news,
          scheduleRepository: ScheduleRepoMock(),
          forumRepository: forum,
          topicRepository: TopicRepoMock(),
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider.value(value: theme),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      ),
    );
    auth.add(AuthGetProfileDataRequested());
    await tester.pumpAndSettle();
    if (!registration) {
      await tester.tap(find.text('Профиль').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать профиль'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> submit(WidgetTester tester, bool registration) async {
    final button = find.text(
      registration ? 'Завершить регистрацию' : 'Сохранить изменения',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await auth.close();
      await theme.close();
      await RegistrationDraftStorage.clearAll();
    });
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RegistrationDraftStorage.memoryPendingUid = null;
  });

  final cases = <(String, String, String, String?, String?)>[
    ('name30 astral', 'Имя в профиле', '${'a' * 29}😀', 'display_name', null),
    (
      'name31',
      'Имя в профиле',
      '${'a' * 30}😀',
      null,
      'Имя для профиля — не длиннее 30 символов',
    ),
    ('name single', 'Имя в профиле', 'Я', 'display_name', null),
    (
      'name blank',
      'Имя в профиле',
      '  ',
      null,
      'Укажи, как тебя показывать в профиле',
    ),
    (
      'group20 astral',
      'Номер группы (необязательно)',
      '${'a' * 19}😀',
      'group_code',
      null,
    ),
    (
      'group21',
      'Номер группы (необязательно)',
      '${'a' * 20}😀',
      null,
      'Номер группы — не длиннее 20 символов',
    ),
    ('bio70 ASCII', 'О себе (необязательно)', 'a' * 70, 'bio', null),
    (
      'bio71 ASCII',
      'О себе (необязательно)',
      'a' * 71,
      null,
      'О себе — не длиннее 70 символов',
    ),
    ('bio70 astral', 'О себе (необязательно)', '😀' * 70, 'bio', null),
    (
      'bio71 astral',
      'О себе (необязательно)',
      '😀' * 71,
      null,
      'О себе — не длиннее 70 символов',
    ),
    ('bio70 combining', 'О себе (необязательно)', 'e\u0301' * 35, 'bio', null),
    (
      'bio72 combining',
      'О себе (необязательно)',
      'e\u0301' * 36,
      null,
      'О себе — не длиннее 70 символов',
    ),
    (
      'handle32',
      'Telegram (необязательно)',
      'a' * 32,
      'messenger_handle',
      null,
    ),
    (
      'handle @32',
      'Telegram (необязательно)',
      '@${'a' * 32}',
      'messenger_handle',
      null,
    ),
    (
      'handle tg32',
      'Telegram (необязательно)',
      ' tg/ @${'a' * 32} ',
      'messenger_handle',
      null,
    ),
    (
      'handle33',
      'Telegram (необязательно)',
      'a' * 33,
      null,
      'Telegram — не длиннее 32 символов',
    ),
    (
      'handle prefixed33',
      'Telegram (необязательно)',
      '@${'a' * 33}',
      null,
      'Telegram — не длиннее 32 символов',
    ),
    (
      'handle32 astral',
      'Telegram (необязательно)',
      '@${'a' * 31}😀',
      'messenger_handle',
      null,
    ),
    (
      'handle single',
      'Telegram (необязательно)',
      '@я',
      'messenger_handle',
      null,
    ),
    (
      'handle double prefix',
      'Telegram (необязательно)',
      '@@name',
      'messenger_handle',
      null,
    ),
    (
      'handle clear',
      'Telegram (необязательно)',
      ' tg/ @',
      'messenger_handle',
      null,
    ),
    ('group clear', 'Номер группы (необязательно)', ' ', 'group_code', null),
    ('bio clear', 'О себе (необязательно)', ' ', 'bio', null),
  ];
  for (final registration in [true, false]) {
    for (final (name, label, input, jsonKey, error) in cases) {
      testWidgets(
        '${registration ? 'registration' : 'edit'} $name uses API bounds without truncation',
        (tester) async {
          final h = ProfileHarness();
          await h.pump(tester, registration);
          expect(
            tester.widget<TextField>(field('Имя в профиле')).controller!.text,
            'Alice',
          );
          await tester.enterText(field(label), input);
          expect(
            tester.widget<TextField>(field(label)).controller!.text,
            input,
          );
          await h.submit(tester, registration);
          expect(tester.takeException(), isNull);
          if (error != null) {
            expect(h.updates, isEmpty);
            expect(find.text(error), findsOneWidget);
            expect(
              tester.widget<TextField>(field(label)).controller!.text,
              input,
            );
          } else {
            expect(h.updates, hasLength(1));
            final expected = input.trim();
            var isClear = expected.isEmpty;
            if (jsonKey == 'messenger_handle') {
              isClear = name == 'handle clear';
            }
            expect(h.updates.single[jsonKey], isClear ? null : expected);
            expect(
              find.byType(
                registration ? RegistrationProfileScreen : ProfileEditScreen,
              ),
              findsNothing,
            );
          }
          await h.close(tester);
        },
      );
    }
    for (final count in [16, 17]) {
      testWidgets(
        '${registration ? 'registration' : 'edit'} avatar$count counts codepoints',
        (tester) async {
          final h = ProfileHarness();
          await h.pump(tester, registration, avatar: '😀' * count);
          await h.submit(tester, registration);
          expect(h.updates, count == 16 ? hasLength(1) : isEmpty);
          if (count == 17) {
            expect(find.text('Смайлик слишком длинный'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await h.close(tester);
        },
      );
    }
  }
}
