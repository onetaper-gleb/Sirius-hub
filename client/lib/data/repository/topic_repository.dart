import 'package:dio/dio.dart';

import '../../domain/model/forum_models/comment_model.dart';
import '../source/firebase_auth_source.dart';

class TopicRepository {
  final FirebaseAuthDataSource _authDataSource;
  final Dio _dio;

  TopicRepository({
    required Dio dio,
    required FirebaseAuthDataSource authDataSource,
  }) : _dio = dio,
       _authDataSource = authDataSource;

  final List<CommentModel> _mockComments = [
    const CommentModel(
      id: '1',
      author_id: 'Daniel',
      content: 'first comment!',
      topicId: '1',
      repliesIds: [],
    ),
    const CommentModel(
      id: '2',
      author_id: 'Hleb',
      content: 'another comment',
      topicId: '1',
      repliesIds: [],
    ),
    const CommentModel(
      id: '3',
      author_id: 'Varya',
      content: 'yet another comment',
      topicId: '2',
      repliesIds: [],
    ),
  ];

  Future<List<CommentModel>> getComments(String topicId) async {
    // return List.from(_mockComments.where((x) => x.topicId == topicId));
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }
      final response = await _dio.get(
        '/topic/comments',
        queryParameters: {'topic_id': topicId},
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        print(response.data);
        return data
            .map(
              (json) =>
                  CommentModel.fromJson(Map<String, dynamic>.from(json as Map)),
            )
            .toList();
      } else {
        throw Exception("Не удалось загрузить комментарии");
      }
    } on DioException catch (e) {
      throw Exception("Ошибка сети при загрузке топиков: ${e.message}");
    } catch (e) {
      throw Exception("Неизвестная ошибка: $e");
    }
  }

  // Future<void> createComment(String content, String topicId) async {
  Future<void> createComment(
    String content,
    String topicId,
    String? parentCommentId,
  ) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }

      // final data = {"topic_id": topicId, "content": content};
      final data = {
        "topic_id": topicId,
        "content": content,
        "parent_comment_id": parentCommentId,
      };

      await _dio.post(
        '/topic/comments',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final errorDetail =
          (data is Map ? data['detail'] : data)?.toString() ?? e.message;
      print(errorDetail);
      throw Exception("Ошибка создания комментария: $errorDetail");
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен');
      }

      await _dio.delete(
        '/topic/comments/$commentId',
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final errorDetail =
          (data is Map ? data['detail'] : data)?.toString() ?? e.message;
      print(errorDetail);
      throw Exception("Ошибка удаления комментария: $errorDetail");
    }
  }

  Future<void> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        throw Exception('Не удалось получить токен');
      }

      final trimmedContent = content.trim();

      if (trimmedContent.isEmpty) {
        throw Exception('Комментарий не может быть пустым');
      }
      if (trimmedContent.length > 500) {
        throw Exception('Длина комментария не должна превышать 500 символов');
      }


      await _dio.patch(
        '/topic/comments/$commentId',
        data: {"content": trimmedContent},
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );

    } on DioException catch (e) {
      final data = e.response?.data;
      final errorDetail =
          (data is Map ? data['detail'] : data)?.toString() ?? e.message;
      print(errorDetail);
      throw Exception("Ошибка обновления комментария: $errorDetail");
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
