import '../../network/api_error.dart';
import 'package:client/domain/model/profile_model.dart';
import 'package:dio/dio.dart';
import 'package:client/data/local/registration_draft_storage.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/data/source/source.dart';

class AuthRepository {
  final AuthDataSource _authDataSource;
  final Dio _dio;

  AuthRepository({required AuthDataSource authDataSource, required Dio dio})
    : _authDataSource = authDataSource,
      _dio = dio;

  Stream<UserModel?> get userStream {
    return _authDataSource.authStateChanges.map((user) {
      if (user == null) return null;
      return UserModel(id: user.uid, email: user.email ?? '');
    });
  }

  bool get isSignedIn => _authDataSource.currentUser != null;

  String? get currentUserId => _authDataSource.currentUser?.uid;

  Future<void> signUp({required String email, required String password}) async {
    final user = await _authDataSource.signUp(email: email, password: password);
    RegistrationDraftStorage.memoryPendingUid = user.uid;
  }

  Future<UserModel> completeRegistration(
    RegistrationProfileData profile,
  ) async {
    await _authDataSource.setUserDisplayName(profile.displayName?.trim() ?? '');
    final token = await _authDataSource.getToken(forceRefresh: true);
    if (token == null) throw Exception('Не удалось получить токен');
    final options = Options(headers: {'Authorization': 'Bearer $token'});
    try {
      if (_authDataSource.needsBackendInit) {
        await _dio.post(
          'auth/init',
          data: {'group_code': profile.groupCode},
          options: options,
        );
      }
      await _dio.put(
        'profile/update',
        data: _profileUpdateJson(profile),
        options: options,
      );
      await _dio.patch(
        'profile/avatar',
        data: {'avatar_emoji': profile.avatarEmoji?.trim() ?? '😀'},
        options: options,
      );
    } on DioException catch (error) {
      throw Exception(
        apiErrorDetail(error.response?.data) ??
            error.message ??
            'Ошибка сервера',
      );
    }
    final uid = currentUserId;
    if (uid == null) throw Exception('Сессия потеряна после регистрации');
    return (await getCurrentProfile()).userModel;
  }

  Map<String, dynamic> _profileUpdateJson(RegistrationProfileData profile) => {
    'display_name': profile.displayName?.trim(),
    'group_code': profile.groupCode?.trim(),
    'messenger_handle': profile.telegramHandle?.trim(),
    'bio': profile.bio?.trim(),
  };

  Future<void> signIn({required String email, required String password}) async {
    await _authDataSource.signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    await _authDataSource.signOut();
  }

  Future<void> abandonIncompleteRegistration() async {
    await _authDataSource.signOut();
  }

  String? get currentEmail => _authDataSource.currentUser?.email;

  Future<ProfileModel> getCurrentProfile() async {
    final data = await _getProfileJson();
    final uid = currentUserId;
    if (uid == null) throw Exception('Сессия завершена');
    return ProfileModel(
      registrationProfileData: RegistrationProfileData.fromJson(data),
      userModel: UserModel.fromResponse(uid, currentEmail, data),
    );
  }

  Future<RegistrationProfileData> getProfileData() async {
    final data = await _getProfileJson();
    return RegistrationProfileData.fromJson(data);
  }

  Future<Map<String, dynamic>> _getProfileJson() async {
    final token = await _authDataSource.getToken(forceRefresh: true);
    if (token == null) throw Exception('Не удалось получить токен');
    final response = await _dio.get(
      'profile/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is! Map<String, dynamic>)
      throw Exception('Неправильный формат профиля');
    return response.data as Map<String, dynamic>;
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
          apiErrorDetail(dioError.response?.data) ??
          dioError.message ??
          'Ошибка сервера';
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
          apiErrorDetail(dioError.response?.data) ??
          dioError.message ??
          'Ошибка сервера';
      throw Exception(errorMessage);
    }

    return await getProfileData();
  }

  Future<bool> hasCompletedBackendProfile() async {
    try {
      final data = await _getProfileJson();
      final name = (data['display_name'] as String?)?.trim();
      final avatar = (data['avatar_emoji'] as String?)?.trim();
      return name != null &&
          name.isNotEmpty &&
          avatar != null &&
          avatar.isNotEmpty;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return false;
      rethrow;
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
        options: Options(headers: {'Authorization': 'Bearer $token'}),
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
}
