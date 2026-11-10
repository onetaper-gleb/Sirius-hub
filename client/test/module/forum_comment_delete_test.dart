import 'package:client/core/dependencies.dart';
import 'package:client/data/repository/topic_repository.dart';
import 'package:client/data/source/auth_source.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/model/registration_profile.dart';
import 'package:client/module/forum/topic_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/json_api.dart';
import 'account_routes_test.dart' show AccountHarness, ScheduleRepoMock;

class SourceMock extends Mock implements AuthDataSource {}

void main() {
  testWidgets('deleting a reply sends its ID and reloads surviving comments', (
    tester,
  ) async {
    final harness = AccountHarness(role: 'student');
    final source = SourceMock();
    when(() => source.getToken()).thenAnswer((_) async => 'token');
    when(() => harness.authRepo.getUser(any())).thenAnswer(
      (_) async => const RegistrationProfileData(
        displayName: 'Alice',
        avatarEmoji: '😀',
      ),
    );
    final comments = [
      for (final (id, parent) in [
        ('root', null),
        ('childA', 'root'),
        ('childB', 'root'),
        ('grandchild', 'childA'),
      ])
        <String, dynamic>{
          'comment_id': id,
          'parent_comment_id': parent,
          'author': 'alice',
          'content': id,
        },
    ];
    final api = JsonApi((request, _) {
      if (request.method == 'DELETE') {
        expect(request.path, '/topic/comments/childA');
        comments.removeWhere((comment) => comment['comment_id'] == 'childA');
        comments.last['parent_comment_id'] = 'root';
        return {'message': 'Comment deleted successfully'};
      }
      expect(request.path, '/topic/comments');
      return comments;
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'))
      ..httpClientAdapter = api;
    final repository = TopicRepository(dio: dio, authDataSource: source);
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: Dependencies(
          authRepository: harness.authRepo,
          newsRepository: harness.news,
          scheduleRepository: ScheduleRepoMock(),
          forumRepository: harness.forum,
          topicRepository: repository,
        ),
        child: BlocProvider<AuthBloc>.value(
          value: harness.auth,
          child: const MaterialApp(
            home: TopicScreen(
              topicId: 'topic',
              title: 'Topic',
              isAnonymous: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('@Alice, childA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить комментарий'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(find.text('@Alice, childA'), findsNothing);
    expect(find.text('@Alice, childB'), findsOneWidget);
    expect(find.text('@Alice, grandchild'), findsOneWidget);
    expect(api.requests.map((request) => request.$1.method), [
      'GET',
      'DELETE',
      'GET',
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    dio.close(force: true);
    await harness.close(tester);
  });
}
