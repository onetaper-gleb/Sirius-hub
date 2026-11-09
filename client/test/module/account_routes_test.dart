import 'dart:async';

import 'package:client/core/dependencies.dart';
import 'package:client/data/repository/repository.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/bloc/news/news_bloc.dart';
import 'package:client/domain/bloc/theme/theme_bloc.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/domain/model/profile_model.dart';
import 'package:client/module/auth/auth_gate.dart';
import 'package:client/module/auth/login_screen.dart';
import 'package:client/module/forum/topic_screen.dart';
import 'package:client/module/news/create_news_screen.dart';
import 'package:client/module/news/news_detail_screen.dart';
import 'package:client/module/news/news_screen.dart';
import 'package:client/module/profile/profile_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'news/news_event_test.dart' as fixtures;

class AuthMock extends Mock implements AuthBloc {}

class AuthRepoMock extends Mock implements AuthRepository {}

class NewsRepoMock extends Mock implements NewsRepository {}

class ScheduleRepoMock extends Mock implements ScheduleRepository {}

class ForumRepoMock extends Mock implements ForumRepository {}

class TopicRepoMock extends Mock implements TopicRepository {}

class AccountHarness {
  final auth = AuthMock();
  final news = NewsRepoMock();
  final forum = ForumRepoMock();
  final topic = TopicRepoMock();
  final authRepo = AuthRepoMock();
  final changes = StreamController<AuthState>.broadcast();
  final theme = ThemeBloc();
  AuthState state;
  final items = <NewsModel>[];

  AccountHarness({String role = 'council'}) : state = signedIn('alice', role) {
    when(() => auth.state).thenAnswer((_) => state);
    when(() => auth.stream).thenAnswer((_) => changes.stream);
    when(() => news.getAllNews()).thenAnswer((_) async => List.of(items));
    when(() => news.getEvent('event')).thenAnswer((_) async => fixtures.event);
    when(() => forum.getTopics()).thenAnswer((_) async => []);
    when(() => topic.getComments(any())).thenAnswer((_) async => []);
  }

  static AuthAuthenticated signedIn(String id, String role) =>
      AuthAuthenticated(
        profileModel: ProfileModel(
          registrationProfileData: const RegistrationProfileData(
            displayName: 'Alice',
            avatarEmoji: '😀',
          ),
          userModel: UserModel(
            id: id,
            email: '$id@example.test',
            role: UserRole.fromString(role),
          ),
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: Dependencies(
          authRepository: authRepo,
          newsRepository: news,
          scheduleRepository: ScheduleRepoMock(),
          forumRepository: forum,
          topicRepository: topic,
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<ThemeBloc>.value(value: theme),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> change(WidgetTester tester, AuthState next) async {
    state = next;
    changes.add(next);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await changes.close();
      await theme.close();
    });
  }
}

NewsModel item({bool event = false, bool topic = false}) => NewsModel(
  id: 'news',
  title: 'Private title',
  content: 'Private body',
  authorId: 'author',
  createdAt: DateTime(2026),
  hasEvent: event,
  eventId: event ? 'event' : null,
  hasTopic: topic,
  topicId: topic ? 'topic' : null,
  anon: false,
);

void main() {
  for (final role in ['council', 'admin']) {
    for (final hasEvent in [false, true]) {
      testWidgets(
        '$role creates ${hasEvent ? 'event' : 'news'} from account FAB and refreshes feed',
        (tester) async {
          final h = AccountHarness(role: role);
          when(
            () => h.news.createNews(
              title: 'New title',
              content: 'New body',
              hasEvent: hasEvent,
              hasTopic: false,
              anon: false,
              imageFile: null,
              eventStatus: hasEvent ? EventStatus.published : null,
              eventStart: hasEvent ? '2026-11-09T00:00:00.000' : null,
              eventEnd: hasEvent ? '2026-11-10T00:00:00.000' : null,
              location: hasEvent ? 'Campus' : null,
              maxParticipants: hasEvent ? 50 : null,
              isRegOpen: false,
            ),
          ).thenAnswer((_) async {
            final created = item(event: hasEvent);
            h.items.add(created);
            return created;
          });
          await h.pump(tester);
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(CreateNewsScreen), findsOneWidget);
          await tester.enterText(find.byType(TextField).at(0), 'New title');
          await tester.enterText(find.byType(TextField).at(1), 'New body');
          if (hasEvent) {
            await tester.tap(find.text('Добавить событие'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField).at(2), '09.11.2026');
            await tester.enterText(find.byType(TextField).at(3), '10.11.2026');
            await tester.enterText(find.byType(TextField).at(4), 'Campus');
            await tester.enterText(find.byType(TextField).at(5), '50');
            await tester.tap(find.byType(DropdownButtonFormField<EventStatus>));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Опубликовано').last);
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.text('Сохранить'));
          await tester.tap(find.text('Сохранить'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(CreateNewsScreen), findsNothing);
          expect(find.text('Private title'), findsOneWidget);
          await h.close(tester);
        },
      );
    }
  }

  for (final route in [
    'detail',
    'topic',
    'profile',
    'avatar',
    'registration',
    'delete',
    'rooms',
    'time',
    'create',
  ]) {
    for (final switchUid in [false, true]) {
      testWidgets(
        '${switchUid ? 'UID switch' : 'logout/401'} removes $route and account blocs',
        (tester) async {
          final h = AccountHarness();
          h.items.add(item(event: true, topic: true));
          await h.pump(tester);
          final oldBloc = tester
              .element(find.byType(NewsScreen))
              .read<NewsBloc>();
          if (['detail', 'topic', 'registration'].contains(route)) {
            await tester.tap(find.text('Private title'));
            await tester.pumpAndSettle();
            expect(find.byType(NewsDetailScreen), findsOneWidget);
            if (route == 'topic') {
              await tester.tap(find.text('Прокомментировать'));
            }
            if (route == 'registration') {
              await tester.tap(find.text('Зарегистрироваться'));
            }
          } else if (route == 'profile' || route == 'avatar') {
            await tester.tap(find.text('Профиль').last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Редактировать профиль'));
            if (route == 'avatar') {
              await tester.pumpAndSettle();
              await tester.tap(find.text('😀').last);
            }
          } else if (route == 'delete') {
            await tester.longPress(find.text('Private title'));
          } else if (route == 'create') {
            await tester.tap(find.byType(FloatingActionButton));
          } else {
            await tester.tap(find.text('Расписание').last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Свободные ауд.'));
            await tester.pumpAndSettle();
            if (route == 'time') {
              await tester.tap(find.text('С:'));
            }
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (route == 'registration') {
            await tester.enterText(find.byType(TextField), 'Draft');
          }
          await h.change(
            tester,
            switchUid
                ? AccountHarness.signedIn('bob', 'student')
                : AuthUnauthenticated(),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(NewsDetailScreen), findsNothing);
          expect(find.byType(TopicScreen), findsNothing);
          expect(find.byType(ProfileEditScreen), findsNothing);
          expect(find.byType(CreateNewsScreen), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(Dialog), findsNothing);
          expect(find.text('Выбери смайлик'), findsNothing);
          expect(oldBloc.isClosed, isTrue);
          if (!switchUid) {
            expect(find.byType(LoginScreen), findsOneWidget);
            await h.change(tester, AccountHarness.signedIn('bob', 'student'));
          }
          expect(find.byType(NewsScreen), findsOneWidget);
          expect(
            tester.element(find.byType(NewsScreen)).read<NewsBloc>(),
            isNot(same(oldBloc)),
          );
          await h.close(tester);
        },
      );
    }
  }

  for (final role in ['student', 'council', 'admin']) {
    testWidgets(
      '$role news moderation and forum creation match council rights',
      (tester) async {
        final h = AccountHarness(role: role);
        h.items.add(item());
        await h.pump(tester);
        final allowed = role != 'student';
        expect(
          find.byType(FloatingActionButton),
          allowed ? findsOneWidget : findsNothing,
        );
        await tester.longPress(find.text('Private title'));
        await tester.pumpAndSettle();
        expect(
          find.text('Удалить новость?'),
          allowed ? findsOneWidget : findsNothing,
        );
        if (allowed) {
          await tester.tap(find.text('Отмена'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Форум').last);
        await tester.pumpAndSettle();
        expect(
          find.byType(FloatingActionButton),
          allowed ? findsOneWidget : findsNothing,
        );
        if (allowed) {
          when(() => h.forum.createTopic('Я', false)).thenAnswer(
            (_) async => TopicModel(
              id: 'topic',
              title: 'Я',
              isAnonymous: false,
              repliesCount: 0,
            ),
          );
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Я');
          await tester.tap(find.text('Создать'));
          await tester.pumpAndSettle();
          verify(() => h.forum.createTopic('Я', false)).called(1);
        }
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }

  test('role parsing retains admin and defaults unknown roles to student', () {
    for (final role in ['student', 'council', 'admin']) {
      expect(UserRole.fromString(role).name, role);
      expect(
        UserModel.fromResponse('user', null, {'role': role}).role.name,
        role,
      );
    }
    expect(UserRole.fromString('unknown'), UserRole.student);
  });

  testWidgets('student submits a single-character forum comment', (
    tester,
  ) async {
    final h = AccountHarness(role: 'student');
    h.items.add(item(topic: true));
    when(
      () => h.topic.createComment('Я', 'topic', null),
    ).thenAnswer((_) async {});
    await h.pump(tester);
    await tester.tap(find.text('Private title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Прокомментировать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Я');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    verify(() => h.topic.createComment('Я', 'topic', null)).called(1);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  for (final role in ['student', 'council', 'admin']) {
    testWidgets(
      '$role can moderate another author comment only with council rights',
      (tester) async {
        final h = AccountHarness(role: role);
        h.items.add(item(topic: true));
        when(() => h.topic.getComments('topic')).thenAnswer(
          (_) async => [
            const CommentModel(
              id: 'comment',
              author_id: 'other',
              content: 'Other comment',
              topicId: 'topic',
              repliesIds: [],
            ),
          ],
        );
        when(() => h.authRepo.getUser('other')).thenAnswer(
          (_) async => const RegistrationProfileData(
            displayName: 'Other',
            avatarEmoji: '😀',
          ),
        );
        when(() => h.topic.deleteComment('comment')).thenAnswer((_) async {});
        await h.pump(tester);
        await tester.tap(find.text('Private title'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Прокомментировать'));
        await tester.pumpAndSettle();
        await tester.longPress(find.text('Other comment'));
        await tester.pumpAndSettle();
        expect(
          find.text('Удалить комментарий'),
          role == 'student' ? findsNothing : findsOneWidget,
        );
        if (role != 'student') {
          await tester.tap(find.text('Удалить комментарий'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Удалить'));
          await tester.pumpAndSettle();
          verify(() => h.topic.deleteComment('comment')).called(1);
        } else {
          verifyNever(() => h.topic.deleteComment('comment'));
        }
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }

  for (final route in ['detail', 'create']) {
    testWidgets(
      'system back closes $route and reaches platform exit at account root',
      (tester) async {
        final h = AccountHarness();
        h.items.add(item());
        var platformPops = 0;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'SystemNavigator.pop') platformPops++;
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await h.pump(tester);
        if (route == 'detail') {
          await tester.tap(find.text('Private title'));
        } else {
          await tester.tap(find.byType(FloatingActionButton));
        }
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(NewsDetailScreen), findsNothing);
        expect(find.byType(CreateNewsScreen), findsNothing);
        expect(find.byType(NewsScreen), findsOneWidget);
        expect(platformPops, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(platformPops, 1);
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }
}
