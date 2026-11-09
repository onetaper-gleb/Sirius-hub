import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_source.dart';

abstract class SessionTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureSessionTokenStore implements SessionTokenStore {
  const SecureSessionTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'sirius_access_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class JwtAuthDataSource implements AuthDataSource {
  JwtAuthDataSource({required Dio dio, required SessionTokenStore tokenStore})
    : _dio = dio,
      _tokenStore = tokenStore {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              _token != null &&
              error.requestOptions.headers['Authorization'] ==
                  'Bearer $_token') {
            try {
              await signOut();
            } catch (_) {
              handler.next(error);
              return;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionTokenStore _tokenStore;
  final _changes = StreamController<AuthUser?>.broadcast(sync: true);
  String? _token;
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get needsBackendInit => false;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
    );
    controller.addSync(_user);
    controller.onCancel = subscription.cancel;
  });

  Future<void> restoreSession() async {
    _token = await _tokenStore.read();
    if (_token == null) return;
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(_token!.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
      final expires = claims['exp'];
      if (expires is! num ||
          expires * 1000 <= DateTime.now().millisecondsSinceEpoch ||
          claims['sub'] is! String) {
        await signOut();
        return;
      }
      _user = AuthUser(
        uid: claims['sub'] as String,
        email: claims['email'] as String?,
      );
    } on FormatException {
      await signOut();
      return;
    } on RangeError {
      await signOut();
      return;
    } on TypeError {
      await signOut();
      return;
    }
    try {
      await _loadUser();
    } on DioException {
      // The repository retries the profile request when the network returns.
    }
  }

  Future<AuthUser> _loadUser() async {
    final token = _token;
    final response = await _dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (_token != token) throw Exception('Сессия завершена');
    final data = response.data as Map<String, dynamic>;
    return _user = AuthUser(
      uid: data['id'] as String,
      email: data['email'] as String?,
    );
  }

  Future<AuthUser> _authenticate(
    String path,
    Object data, {
    bool form = false,
  }) async {
    final response = await _dio.post(
      path,
      data: data,
      options: Options(
        contentType: form
            ? Headers.formUrlEncodedContentType
            : Headers.jsonContentType,
      ),
    );
    final token = (response.data as Map<String, dynamic>)['access_token'];
    if (token is! String || token.isEmpty) {
      throw Exception('Сервер не вернул токен');
    }
    _token = token;
    try {
      final user = await _loadUser();
      await _tokenStore.write(token);
      _changes.add(user);
      return user;
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<AuthUser> signUp({required String email, required String password}) =>
      _authenticate('/auth/register', {'email': email, 'password': password});

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _authenticate('/auth/token', {
        'username': email,
        'password': password,
      }, form: true);

  @override
  Future<String?> getToken({bool forceRefresh = false}) async => _token;

  @override
  Future<void> setUserDisplayName(String displayName) async {}

  @override
  Future<void> signOut() async {
    _token = null;
    _user = null;
    _changes.add(null);
    await _tokenStore.clear();
  }
}
