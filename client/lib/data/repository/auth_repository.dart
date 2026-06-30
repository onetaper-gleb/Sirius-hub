import 'package:client/core/api_config.dart';
import 'package:client/domain/model/profile_model.dart';
import 'package:dio/dio.dart';
import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/data/source/source.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class AuthRepository {
  final FirebaseAuthDataSource _authDataSource;
  final UserFirestoreDataSource _firestoreDataSource;
  final Dio _dio;

  AuthRepository({
    required FirebaseAuthDataSource authDataSource,
    required UserFirestoreDataSource firestoreDataSource,
    required Dio dio,
  }) : _authDataSource = authDataSource,
       _firestoreDataSource = firestoreDataSource,
       _dio = dio;

  Stream<UserModel?> get userStream {
    return _authDataSource.authStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return await _fetchUserOrCreateDefault(
        firebaseUser.uid,
        firebaseUser.email,
      );
    });
  }

  bool get isFirebaseSignedIn => _authDataSource.currentUser != null;

  String? get currentFirebaseUid => _authDataSource.currentUser?.uid;

  Future<void> signUpFirebaseOnly({
    required String email,
    required String password,
  }) async {
    final firebaseUser = await _authDataSource.signUp(
      email: email,
      password: password,
    );
    RegistrationDraftStorage.memoryPendingUid = firebaseUser.uid;
  }

  Future<UserModel> completeRegistration(
    RegistrationProfileData profile,
  ) async {
    try {
      final email = _authDataSource.currentUser?.email ?? '';
      await _authDataSource.setUserDisplayName(
        profile.displayName == null ? '' : profile.displayName!.trim(),
      );

      final rawToken = await _authDataSource.getToken(forceRefresh: true);
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }

      final authOptions = Options(
        headers: {'Authorization': 'Bearer $rawToken'},
      );

      try {
        await _dio.post('auth/init', options: authOptions);
      } on DioException catch (dioError) {
        await _authDataSource.deleteCurrentUser();
        final errorMessage =
            _extractApiDetail(dioError) ?? dioError.message ?? 'Ошибка сервера';
        throw Exception(errorMessage);
      }

      try {
        await _dio.put(
          'profile/update',
          data: _profileUpdateJson(profile),
          options: authOptions,
        );
      } on DioException catch (dioError) {
        await _authDataSource.deleteCurrentUser();
        final errorMessage =
            _extractApiDetail(dioError) ?? dioError.message ?? 'Ошибка сервера';
        throw Exception(errorMessage);
      }

      try {
        await _dio.patch(
          'profile/avatar',
          data: {
            'avatar_emoji': profile.avatarEmoji != null
                ? profile.avatarEmoji!.trim()
                : '😀',
          },
          options: authOptions,
        );
      } on DioException catch (dioError) {
        await _authDataSource.deleteCurrentUser();
        final errorMessage =
            _extractApiDetail(dioError) ?? dioError.message ?? 'Ошибка сервера';
        throw Exception(errorMessage);
      }

      await _authDataSource.getToken(forceRefresh: true);

      final uid = _authDataSource.currentUser?.uid;
      if (uid == null) {
        throw Exception('Сессия потеряна после регистрации');
      }

      final newUser = UserModel(
        id: uid,
        email: email,
        role: UserRole.student,
        name: profile.displayName == null ? '' : profile.displayName!.trim(),
      );
      await _firestoreDataSource.saveUser(newUser);

      return newUser;
    } on firebase.FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _profileUpdateJson(RegistrationProfileData p) {
    final displayName = p.displayName == null ? '' : p.displayName!.trim();
    final map = <String, dynamic>{'display_name': displayName};
    final group = p.groupCode?.trim();
    if (group != null && group.isNotEmpty) {
      map['group_code'] = group;
    }
    final tg = p.telegramHandle?.trim();
    if (tg != null && tg.isNotEmpty) {
      map['telegram_handle'] = tg;
    }
    final bio = p.bio?.trim();
    if (bio != null && bio.isNotEmpty) {
      map['bio'] = bio;
    }
    return map;
  }

  String? _extractApiDetail(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final msgs = <String>[];
        for (final item in detail) {
          if (item is Map && item['msg'] != null) {
            msgs.add(item['msg'].toString());
          }
        }
        if (msgs.isNotEmpty) return msgs.join('; ');
      }
    }
    return null;
  }

  Future<ProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    final firebaseUser = await _authDataSource.signIn(
      email: email,
      password: password,
    );
    final auth = await _fetchUserOrCreateDefault(
      firebaseUser.uid,
      firebaseUser.email,
    );

    final model = await getProfileData();
    final authModel = ProfileModel(
      registrationProfileData: model,
      userModel: auth,
    );
    return authModel;
      // String? token = await _authDataSource.getToken(forceRefresh: true);
      // print("Bearer "+ token.toString());
  }

  Future<void> signOut() async {
    await _authDataSource.signOut();
  }

  Future<void> abandonIncompleteRegistration() async {
    try {
      await _authDataSource.deleteCurrentUser();
    } catch (_) {
      // требуется недавний вход и т.п. — всё равно чистим сессию
    }
    await _authDataSource.signOut();
  }

  Future<RegistrationProfileData> getProfileData() async {
    if (await hasCompletedBackendProfile()) {
      final token = await _authDataSource.getToken(forceRefresh: true);
      if (token == null) throw Exception('No token');

      try {
        final response = await _dio.get(
          'profile/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        final data = response.data;


        if (data is! Map<String, dynamic>) {
          throw Exception('Неправильный формат response при логине.');
        }

        final model = RegistrationProfileData.fromJson(data);
        return model;
      } on DioException catch (e) {
        rethrow;
      } catch (e) {
        rethrow;
      }
    } else {
      throw Exception('Не получилось войти в аккаунт');
    }
  }

  Future<RegistrationProfileData> updateProfileData(
    RegistrationProfileData profile,
  ) async {
    final token = await _authDataSource.getToken(forceRefresh: true);
    if (token == null) throw Exception('No token');

    final authOptions = Options(headers: {'Authorization': 'Bearer $token'});

    try {
      await _dio.put(
        'profile/update',
        data: _profileUpdateJson(profile),
        options: authOptions,
      );
    } on DioException catch (dioError) {
      final errorMessage =
          _extractApiDetail(dioError) ?? dioError.message ?? 'Ошибка сервера';
      throw Exception(errorMessage);
    }

    try {
      await _dio.patch(
        'profile/avatar',
        data: {
          'avatar_emoji': profile.avatarEmoji != null
              ? profile.avatarEmoji!.trim()
              : '😀',
        },
        options: authOptions,
      );
    } on DioException catch (dioError) {
      final errorMessage =
          _extractApiDetail(dioError) ?? dioError.message ?? 'Ошибка сервера';
      throw Exception(errorMessage);
    }

    return await getProfileData();
  }

  Future<bool> hasCompletedBackendProfile() async {
    final token = await _authDataSource.getToken(forceRefresh: true);
    if (token == null) return false;

    try {
      final response = await _dio.get(
        'profile/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return false;

      final displayName = (data['display_name'] as String?)?.trim();
      final avatarEmoji = (data['avatar_emoji'] as String?)?.trim();
      return (displayName != null && displayName.isNotEmpty) &&
          (avatarEmoji != null && avatarEmoji.isNotEmpty);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<RegistrationProfileData> getUser(String userId) async {
    if (userId.isEmpty || userId.length < 10) {
      throw Exception('Некорректный идентификатор пользователя');
    }

    final token = await _authDataSource.getToken(forceRefresh: true);
    if (token == null) throw Exception('No token');

    try {
      final response = await _dio.get(
        'profile/user/$userId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return RegistrationProfileData.fromJson(data);
      } else {
        throw Exception('Неправильный формат ответа');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Пользователь не найден');
      }
      throw Exception('Ошибка загрузки профиля: ${e.message}');
    }
  }

  Future<bool> shouldShowRegistrationForUid(String uid) async {
    final pending = await RegistrationDraftStorage.isPendingForUid(uid);
    if (pending) return true;
    return !(await hasCompletedBackendProfile());
  }

  Future<UserModel> _fetchUserOrCreateDefault(String uid, String? email) async {
    final userModel = await _firestoreDataSource.getUser(uid);

    if (userModel != null) {
      return userModel;
    }

    return UserModel(id: uid, email: email ?? '', role: UserRole.student);
  }
}
