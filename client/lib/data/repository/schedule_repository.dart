import 'package:client/core/api_config.dart';
import 'package:client/domain/model/model.dart';
import 'package:dio/dio.dart';

class ScheduleRepository {
  final Dio _dio;

  ScheduleRepository({required Dio dio}) : _dio = dio;

  static const String _url = 'schedule';

  Future<WeekScheduleModel> getSchedule(String group, int weekOffset) async {
    String url = _createLink([group, weekOffset]);
    try {
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        if (data.isEmpty) throw Exception('Такой группы не существует.');
        return WeekScheduleModel.fromJson(data);
      } else if (response.statusCode == 422) {
        throw Exception(
          'Неправильный запрос: ${response.data['detail']['msg']}',
        );
      } else {
        throw Exception(
          "Ошибка при запросе на получение расписания группы ${group}. Код ошибки: ${response.statusCode}",
        );
      }
    } on DioException catch (e) {
      // TODO log error
      print(e);
      rethrow;
    } catch (e) {
      // TODO log error
      rethrow;
    }
  }

  String _createLink(List<Object> args) {
    String link = '${ApiConfig.baseUrl}/${_url}/?';
    link = link + 'group=${args[0]}' + "&" + "week_offset=${args[1]}";
    print(link);
    return link;
  }
}
