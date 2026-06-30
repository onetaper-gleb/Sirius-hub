import 'package:client/domain/model/forum_models/topic_model.dart';
import 'package:dio/dio.dart';

import '../source/firebase_auth_source.dart';

class ForumRepository {
  final FirebaseAuthDataSource _authDataSource;
  final Dio _dio;

  ForumRepository({
    required Dio dio,
    required FirebaseAuthDataSource authDataSource,
  }) : _dio = dio,
       _authDataSource = authDataSource;

  final List<TopicModel> _mockTopics = [
    const TopicModel(
      id: '1',
      title: 'Как начать изучать Flutter в 2026?',
      repliesCount: 42,
      isAnonymous: false,
    ),
    const TopicModel(
      id: '2',
      title: 'Где найти хорошую архитектуру?',
      repliesCount: 15,
      isAnonymous: false,
    ),
    const TopicModel(
      id: '3',
      title: 'Помогите с ошибкой Provider / BLoC',
      repliesCount: 3,
      isAnonymous: false,
    ),
  ];

  Future<List<TopicModel>> getTopics() async {
    // return List.from(_mockTopics);
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }
      final response = await _dio.get(
        '/forum/topics',
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );
      print('=== RESPONSE DATA TYPE: ${response.data.runtimeType}');
      print('=== RESPONSE DATA: ${response.data}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map(
              (json) =>
                  TopicModel.fromJson(Map<String, dynamic>.from(json as Map)),
            )
            .toList();
      } else {
        throw Exception("Не удалось загрузить топики");
      }
    } on DioException catch (e) {
      throw Exception("Ошибка сети при загрузке топиков: ${e.message}");
    } catch (e) {
      throw Exception("Неизвестная ошибка: $e");
    }
  }


  Future<void> createTopic(String title, bool isAnonymous) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }
      final formData = {
        'title': title,
        'anon': isAnonymous,
      };

      final response = await _dio.post(
        '/forum/topics',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );
      print('=== CREATE TOPIC RESPONSE status: ${response.statusCode}');
      print('=== CREATE TOPIC RESPONSE data type: ${response.data.runtimeType}');
      print('=== CREATE TOPIC RESPONSE data: ${response.data}');
    } on DioException catch (e) {
      print('=== DIO EXCEPTION: ${e.message}');
      print('=== RESPONSE status: ${e.response?.statusCode}');
      print('=== RESPONSE data type: ${e.response?.data.runtimeType}');
      print('=== RESPONSE data: ${e.response?.data}');
      if (e.response?.statusCode == 403) {
        throw Exception("Доступ запрещен. Вы не состоите в студсовете.");
      }
      final data = e.response?.data;
      final errorDetail =
          (data is Map ? data['detail'] : data)?.toString() ?? e.message;
      throw Exception("Ошибка создания топика: $errorDetail");
    }
  }
}
