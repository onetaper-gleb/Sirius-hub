import 'dart:convert';

import 'package:client/data/source/jwt_auth_source.dart';
import 'package:client/data/repository/auth_repository.dart';
import 'package:client/domain/model/model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';

class MemoryTokenStore implements SessionTokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

String token({bool expired = false}) {
  final claims = {
    'sub': 'jwt-user',
    'exp':
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600),
  };
  return 'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio dio;
  late MemoryTokenStore store;
  late JwtAuthDataSource source;
  late List<RequestOptions> requests;
  var failProfile = false;
  var failLogin = false;
  var offline = false;
  setUp(() {
    failProfile = false;
    failLogin = false;
    offline = false;
    store = MemoryTokenStore();
    requests = [];
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    source = JwtAuthDataSource(dio: dio, tokenStore: store);
    dio.httpClientAdapter = FakeApi((request) async {
      requests.add(request);
      if (offline)
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        );
      if (request.path == '/auth/token' || request.path == '/auth/register') {
        return FakeApi.json({
          'access_token': token(),
          'token_type': 'bearer',
        }, failLogin ? 401 : 200);
      }
      if (request.path == '/auth/me') {
        return FakeApi.json({
          'id': 'jwt-user',
          'email': 'alice@example.test',
          'role': 'student',
        });
      }
      if (request.path == '/private')
        return FakeApi.json({'detail': 'Expired'}, 401);
      if (failProfile) return FakeApi.json({'detail': 'Unavailable'}, 503);
      return FakeApi.json({
        'display_name': 'Alice',
        'avatar_emoji': '😀',
        'role': 'student',
      });
    });
  });

  test(
    'login uses form credentials, stores token, and fetches the authenticated user',
    () async {
      final user = await source.signIn(
        email: 'alice@example.test',
        password: ' pass word ',
      );
      expect(user.uid, 'jwt-user');
      expect(requests.first.contentType, Headers.formUrlEncodedContentType);
      expect(requests.first.data, {
        'username': 'alice@example.test',
        'password': ' pass word ',
      });
      expect(requests.last.headers['Authorization'], 'Bearer ${store.token}');
      expect(store.token, isNotNull);
    },
  );

  test(
    'JWT signup completes the existing profile without calling Firebase init',
    () async {
      await source.signUp(email: 'alice@example.test', password: 'password123');
      final repo = AuthRepository(dio: dio, authDataSource: source);
      await repo.completeRegistration(
        const RegistrationProfileData(displayName: 'Alice', avatarEmoji: '😀'),
      );
      expect(requests.first.path, '/auth/register');
      expect(requests.first.contentType, Headers.jsonContentType);
      expect(requests.any((r) => r.path.contains('auth/init')), isFalse);
    },
  );

  test('restores secure token and validates it against auth/me', () async {
    store.token = token();
    await source.restoreSession();
    expect(source.currentUser?.uid, 'jwt-user');
    expect(source.currentUser?.email, 'alice@example.test');
    expect(requests.single.path, '/auth/me');
  });

  test('expired and malformed stored tokens clear local credentials', () async {
    for (final value in [token(expired: true), 'invalid', 'a.e30=.c']) {
      store.token = value;
      await source.restoreSession();
      expect(source.currentUser, isNull);
      expect(store.token, isNull);
      expect(await source.getToken(), isNull);
    }
    expect(requests, isEmpty);
  });

  test('offline startup preserves the existing token for retry', () async {
    store.token = token();
    offline = true;
    await source.restoreSession();
    expect(source.currentUser?.uid, 'jwt-user');
    expect(store.token, isNotNull);
    offline = false;
    expect(
      await AuthRepository(
        dio: dio,
        authDataSource: source,
      ).hasCompletedBackendProfile(),
      isTrue,
    );
  });

  test(
    'an authenticated 401 clears secure storage and publishes logout',
    () async {
      await source.signIn(email: 'alice@example.test', password: 'password123');
      final loggedOut = source.authStateChanges.firstWhere(
        (user) => user == null,
      );
      await expectLater(
        dio.get(
          '/private',
          options: Options(headers: {'Authorization': 'Bearer ${store.token}'}),
        ),
        throwsA(isA<DioException>()),
      );
      await loggedOut;
      expect(source.currentUser, isNull);
      expect(store.token, isNull);
    },
  );

  test(
    'explicit logout removes credentials and supports a new login',
    () async {
      await source.signIn(email: 'alice@example.test', password: 'password123');
      await source.signOut();
      expect(source.currentUser, isNull);
      expect(store.token, isNull);
      await source.signIn(email: 'alice@example.test', password: 'password123');
      expect(source.currentUser?.uid, 'jwt-user');
      expect(store.token, isNotNull);
    },
  );

  test('failed login never stores the rejected token', () async {
    failLogin = true;
    await expectLater(
      source.signIn(email: 'alice@example.test', password: 'wrong'),
      throwsA(isA<DioException>()),
    );
    expect(store.token, isNull);
    expect(source.currentUser, isNull);
  });

  test('temporary profile failure preserves the JWT session', () async {
    await source.signUp(email: 'alice@example.test', password: 'password123');
    failProfile = true;
    await expectLater(
      AuthRepository(dio: dio, authDataSource: source).completeRegistration(
        const RegistrationProfileData(displayName: 'Alice', avatarEmoji: '😀'),
      ),
      throwsException,
    );
    expect(source.currentUser?.uid, 'jwt-user');
    expect(store.token, isNotNull);
  });
}
