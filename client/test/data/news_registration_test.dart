import 'dart:convert';
import 'dart:typed_data';

import 'package:client/data/repository/news_repository.dart';
import 'package:client/data/source/source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class SourceMock extends Mock implements AuthDataSource {}

class FormApi implements HttpClientAdapter {
  String? body;
  String? contentType;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    contentType = options.contentType;
    body = utf8.decode(await requestStream!.expand((bytes) => bytes).toList());
    final fields = Uri.splitQueryString(body!);
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'registration',
        'event_id': 'event',
        'user_id': 'user',
        'status': 'registered',
        'comment': fields['comment'],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final comment in [
    'Please reserve an accessible seat',
    'Привет + & 😀',
    '',
    null,
  ]) {
    test('event registration form preserves $comment', () async {
      final source = SourceMock();
      when(() => source.getToken()).thenAnswer((_) async => 'token');
      final api = FormApi();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final registration = await NewsRepository(
        dio: dio,
        authDataSource: source,
      ).registerForEvent(eventId: 'event', comment: comment);
      expect(api.contentType, Headers.formUrlEncodedContentType);
      expect(Uri.splitQueryString(api.body!)['comment'], comment);
      expect(registration.comment, comment);
    });
  }
}
