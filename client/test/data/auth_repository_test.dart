import 'package:client/data/repository/auth_repository.dart';
import 'package:client/data/repository/forum_repository.dart';
import 'package:client/data/repository/news_repository.dart';
import 'package:client/data/repository/topic_repository.dart';
import 'package:client/data/source/source.dart';
import 'package:client/domain/model/model.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_api.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class MockSource extends Mock implements AuthDataSource {}

const profileJson = {
  'id': 'existing-user',
  'email': 'a@b.co',
  'role': 'council',
  'display_name': 'Alice',
  'avatar_emoji': '😀',
  'messenger_handle': 'alice',
};
const profile = RegistrationProfileData(
  displayName: 'Alice',
  avatarEmoji: '😀',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'missing tokens never delete the Firebase account in ordinary requests',
    () async {
      final auth = MockFirebaseAuth();
      final user = MockFirebaseUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('existing-user');
      when(() => user.email).thenReturn('a@b.co');
      when(() => user.getIdToken(any())).thenAnswer((_) async => null);
      final source = FirebaseAuthDataSource(auth: auth);
      final dio = Dio();
      final news = NewsRepository(dio: dio, authDataSource: source);
      final forum = ForumRepository(dio: dio, authDataSource: source);
      final topic = TopicRepository(dio: dio, authDataSource: source);
      final requests = <Future<Object?> Function()>[
        news.getAllNews,
        () => news.createNews(title: 'Title', content: 'Content'),
        () => news.deleteNews('news'),
        () => news.getEvent('event'),
        () => news.registerForEvent(eventId: 'event'),
        forum.getTopics,
        () => forum.createTopic('Topic', false),
        () => topic.getComments('topic'),
        () => topic.createComment('Text', 'topic', null),
        () => topic.deleteComment('comment'),
        () => topic.updateComment(commentId: 'comment', content: 'Text'),
      ];
      for (final request in requests) {
        await expectLater(request(), throwsException);
      }
      verifyNever(() => user.delete());
      verifyNever(() => auth.signOut());
    },
  );

  for (final failingPath in ['auth/init', 'profile/update', 'profile/avatar']) {
    test(
      'registration retains the session after failure at $failingPath',
      () async {
        final source = MockSource();
        when(
          () => source.currentUser,
        ).thenReturn(const AuthUser(uid: 'existing-user', email: 'a@b.co'));
        when(() => source.needsBackendInit).thenReturn(true);
        when(
          () => source.getToken(forceRefresh: true),
        ).thenAnswer((_) async => 'token');
        when(() => source.setUserDisplayName(any())).thenAnswer((_) async {});
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
        dio.httpClientAdapter = FakeApi(
          (options) async => FakeApi.json(
            options.path == failingPath
                ? {'detail': 'Unavailable'}
                : profileJson,
            options.path == failingPath ? 503 : 200,
          ),
        );
        final repo = AuthRepository(authDataSource: source, dio: dio);
        await expectLater(repo.completeRegistration(profile), throwsException);
        expect(repo.isSignedIn, isTrue);
        verifyNever(() => source.signOut());
      },
    );
  }

  test(
    'profile updates send cleared fields and the API messenger name',
    () async {
      final source = MockSource();
      when(
        () => source.getToken(forceRefresh: true),
      ).thenAnswer((_) async => 'token');
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      dio.httpClientAdapter = FakeApi((request) async {
        requests.add(request);
        return FakeApi.json(profileJson);
      });
      final result = await AuthRepository(
        authDataSource: source,
        dio: dio,
      ).updateProfileData(profile);
      expect(requests.first.data, {
        'display_name': 'Alice',
        'group_code': null,
        'messenger_handle': null,
        'bio': null,
      });
      expect(result.telegramHandle, 'alice');
    },
  );

  test(
    'only a missing profile starts registration; connection failure is retriable',
    () async {
      final source = MockSource();
      when(
        () => source.getToken(forceRefresh: true),
      ).thenAnswer((_) async => 'token');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      var status = 404;
      dio.httpClientAdapter = FakeApi(
        (_) async => FakeApi.json({'detail': 'failure'}, status),
      );
      final repo = AuthRepository(authDataSource: source, dio: dio);
      expect(await repo.hasCompletedBackendProfile(), isFalse);
      status = 503;
      await expectLater(
        repo.hasCompletedBackendProfile(),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    'leaving incomplete registration signs out without deleting an account',
    () async {
      final auth = MockFirebaseAuth();
      final user = MockFirebaseUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => auth.signOut()).thenAnswer((_) async {});
      await AuthRepository(
        authDataSource: FirebaseAuthDataSource(auth: auth),
        dio: Dio(),
      ).abandonIncompleteRegistration();
      verify(() => auth.signOut()).called(1);
      verifyNever(() => user.delete());
    },
  );
}
