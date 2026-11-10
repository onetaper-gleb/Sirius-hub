import 'package:client/network/api_error.dart';
import 'package:client/data/repository/forum_repository.dart';
import 'package:client/data/repository/news_repository.dart';
import 'package:client/data/repository/topic_repository.dart';
import 'package:client/data/source/auth_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_api.dart';

class SourceMock extends Mock implements AuthDataSource {}

void main() {
  late Dio dio;
  late SourceMock source;
  setUp(() {
    source = SourceMock();
    when(() => source.getToken()).thenAnswer((_) async => 'token');
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
  });
  tearDown(() => dio.close(force: true));

  test('event HTTP 500 text body preserves the server error', () async {
    dio.httpClientAdapter = FakeApi(
      (_) async => ResponseBody.fromString(
        'Internal Server Error',
        500,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      ),
    );
    await expectLater(
      NewsRepository(dio: dio, authDataSource: source).getEvent('event'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Internal Server Error'),
        ),
      ),
    );
  });

  for (final payload in <Object?>[
    'Internal Server Error',
    ['Internal Server Error'],
    {'detail': 'Internal Server Error'},
    {
      'detail': [
        {
          'loc': ['body', 'content'],
          'msg': 'Internal Server Error',
          'type': 'value_error',
        },
      ],
    },
  ]) {
    test('news operations preserve error for ${payload.runtimeType}', () async {
      dio.httpClientAdapter = FakeApi((_) async => FakeApi.json(payload, 500));
      final repository = NewsRepository(dio: dio, authDataSource: source);
      for (final operation in <Future<Object?> Function()>[
        () => repository.getEvent('event'),
        () => repository.createNews(title: 'title', content: 'content'),
        () => repository.registerForEvent(eventId: 'event'),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('Internal Server Error'),
            ),
          ),
        );
      }
    });
  }

  test('unsupported and empty error bodies use the request fallback', () {
    for (final body in <Object?>[
      null,
      '',
      5,
      true,
      {},
      {'detail': []},
    ]) {
      expect(apiErrorDetail(body), isNull);
    }
  });

  test(
    'forum topic and reply payloads load using backend field names',
    () async {
      dio.httpClientAdapter = FakeApi((options) async {
        if (options.path == '/forum/topics') {
          return FakeApi.json([
            {
              'title': 'тестовы',
              'topic_id': 'topic',
              'responses_count': 7,
              'anon': false,
            },
          ]);
        }
        expect(options.path, '/topic/comments');
        expect(options.queryParameters, {'topic_id': 'topic'});
        return FakeApi.json([
          {
            'content': 'reply',
            'comment_id': 'reply',
            'author': 'author',
            'parent_comment_id': 'parent',
            'reply_to_author': 'author',
          },
          {
            'content': 'parent',
            'comment_id': 'parent',
            'author': 'author',
            'parent_comment_id': null,
            'reply_to_author': null,
          },
        ]);
      });
      final topics = await ForumRepository(
        dio: dio,
        authDataSource: source,
      ).getTopics();
      expect(topics.single.repliesCount, 7);
      final comments = await TopicRepository(
        dio: dio,
        authDataSource: source,
      ).getComments(topics.single.id);
      expect(comments.first.parentCommentId, 'parent');
      expect(comments.first.author_id, 'author');
      expect(comments.last.id, 'parent');
    },
  );
}
