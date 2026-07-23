import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/data/source/source.dart';

class NewsRepository {
  final FirebaseAuthDataSource _authDataSource;
  final Dio _dio;

  NewsRepository({
    required Dio dio,
    required FirebaseAuthDataSource authDataSource,
  }) : _dio = dio,
       _authDataSource = authDataSource;

  Future<List<NewsModel>> getAllNews() async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }
      final response = await _dio.get(
        '/news/',
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => NewsModel.fromJson(json)).toList();
      } else {
        throw Exception("Не удалось загрузить новости");
      }
    } on DioException catch (e) {
      throw Exception("Ошибка сети при загрузке новостей: ${e.message}");
    }
  }

  Future<NewsModel> createNews({
    required String title,
    required String content,
    bool hasEvent = false,
    bool hasTopic = false,
    bool anon = false,
    EventStatus? eventStatus,
    String? eventStart,
    String? eventEnd,
    String? location,
    int? maxParticipants,
    bool? isRegOpen,
    File? imageFile,
  }) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }

      String? imageBytes;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        imageBytes = base64Encode(bytes);
      }

      final requestData = {
        "title": title,
        "content": content,
        "has_event": hasEvent,
        "has_topic": hasTopic,
        "anon": anon,
        "event_status": eventStatus?.value,
        "event_start": eventStart,
        "event_end": eventEnd,
        "location": location,
        "max_partic": maxParticipants,
        "is_reg_open": isRegOpen,
        "image": imageBytes,
      };

      final response = await _dio.post(
        '/news/',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $rawToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      return NewsModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception("Доступ запрещен. Вы не состоите в студсовете.");
      } else if (e.response?.statusCode == 400) {
        throw Exception(
          "Слишком большой файл или неверный формат (макс 2 МБ).",
        );
      }
      final errorDetail = e.response?.data?['detail'] ?? e.message;
      throw Exception("Ошибка создания новости: $errorDetail");
    }
  }

  Future<void> deleteNews(String newsId) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception('Не удалось получить токен после регистрации');
      }
      await _dio.delete(
        '/news/$newsId',
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception(
          "Доступ запрещен. Только студсовет может удалять новости.",
        );
      } else if (e.response?.statusCode == 404) {
        throw Exception("Новость не найдена (возможно, уже удалена).");
      }
      throw Exception("Ошибка удаления: ${e.message}");
    }
  }

  Future<RegistrationModel> registerForEvent({
    required String eventId,
    String? comment,
  }) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception("Не удалось получить токен");
      }

      final response = await _dio.post(
        '/news/events/$eventId/register',
        data: {"comment": comment},
        options: Options(
          headers: {
            'Authorization': 'Bearer $rawToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return RegistrationModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception("Регистрация закрыта или нет доступа.");
      } else if (e.response?.statusCode == 404) {
        throw Exception("Событие не найдено.");
      } else if (e.response?.statusCode == 409) {
        throw Exception("Вы уже зарегистрированы.");
      }
      final errorDetail = e.response?.data?['detail'] ?? e.message;
      throw Exception("Ошибка регистрации: $errorDetail");
    }
  }

  Future<EventModel> getEvent(String eventId) async {
    try {
      final rawToken = await _authDataSource.getToken();
      if (rawToken == null) {
        await _authDataSource.deleteCurrentUser();
        throw Exception("Не удалось получить токен");
      }

      final response = await _dio.get(
        '/news/events/$eventId',
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
      );

      return EventModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception("Событие не найдено");
      }
      final errorDetail = e.response?.data?['detail'] ?? e.message;
      throw Exception("Ошибка получения события: $errorDetail");
    }
  }
}
