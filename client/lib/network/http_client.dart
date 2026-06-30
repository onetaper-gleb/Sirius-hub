import 'package:client/core/api_config.dart';
import 'package:dio/dio.dart';

Dio createAppHttpClient() {
  return Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}/',
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );
}
