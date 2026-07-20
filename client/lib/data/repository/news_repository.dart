import 'dart:io';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
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
    String? eventStatus,
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

      final Map<String, dynamic> requestData = {
        "title": title,
        "content": content,
        "has_event": hasEvent,
        "has_topic": hasTopic,
        "anon": anon,
        "event_status": eventStatus,
        "event_start": eventStart,
        "event_end": eventEnd,
        "location": location,
        "max_partic": maxParticipants,
        "is_reg_open": isRegOpen,
      };
      final formData = FormData();
      formData.files.add(MapEntry(
        "request",
        MultipartFile.fromString(
          jsonEncode(requestData),
          contentType: MediaType('application', 'json'),
        ),
      ));

      if (imageFile != null) {
        formData.files.add(MapEntry(
          "image",
          await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
        ));
      }

      final response = await _dio.post(
        '/news/',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $rawToken'}),
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
}
