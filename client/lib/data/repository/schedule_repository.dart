import 'package:client/core/api_config.dart';
import 'package:client/domain/model/model.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:client/data/local/app_database.dart';
import 'package:client/data/local/local_settings.dart';

class ScheduleRepository {
  final Dio _dio;
  final AppDatabase _db;
  final LocalSettings _localSettings;

  ScheduleRepository({
    required Dio dio,
    required AppDatabase db,
    required LocalSettings localSettings,
  }) : _dio = dio,
       _db = db,
       _localSettings = localSettings;

  Future<WeekScheduleModel> getSchedule(String group, int weekOffset) async {
    if (weekOffset != 0) {
      try {
        String url =
            '${ApiConfig.baseUrl}/schedule/?group=$group&week_offset=$weekOffset';
        var response = await _dio.get(url);

        if (response.statusCode == 200) {
          if ((response.data as List).isEmpty) {
            throw Exception('Такой группы не существует.');
          }
          return WeekScheduleModel.fromJson(response.data);
        } else {
          throw Exception("Ошибка при запросе расписания");
        }
      } catch (e) {
        String errorText = e.toString().toLowerCase();
        if (errorText.contains('connection') || errorText.contains('socket')) {
          throw Exception(
            'Нет подключения к интернету 🌐\nКэш работает только для текущей недели.',
          );
        }

        print('Ошибка при загрузке другой недели: $e');
        throw Exception('Не удалось загрузить данные. Попробуйте позже.');
      }
    }

    int now = DateTime.now().millisecondsSinceEpoch;
    int lastSync = _localSettings.getLastSyncTime() ?? 0;

    bool isCacheFresh = (now - lastSync) < 7200000;

    var cachedEvents = await _db.getCachedSchedule(group);

    if (isCacheFresh == true && cachedEvents.isNotEmpty) {
      print('>>> Взяли расписание из БД');
      return _mapDbToModel(cachedEvents);
    }

    try {
      String url =
          '${ApiConfig.baseUrl}/schedule/?group=$group&week_offset=$weekOffset';
      var response = await _dio.get(url);

      if (response.statusCode == 200) {
        var data = response.data as List;
        if (data.isEmpty) throw Exception('Такой группы не существует.');

        var networkModel = WeekScheduleModel.fromJson(data);

        await _db.clearGroupSchedule(group);
        var companions = _mapModelToCompanions(networkModel, group);
        await _db.insertSchedule(companions);

        await _localSettings.saveLastSyncTime(now);
        await _localSettings.saveSelectedGroup(group);

        print('>>> Скачали из сети и сохранили в БД');
        return networkModel;
      } else {
        throw Exception("Ошибка. Код: ${response.statusCode}");
      }
    } catch (e) {
      print('Ошибка при загрузке: $e');
      if (cachedEvents.isNotEmpty) {
        return _mapDbToModel(cachedEvents);
      }
      rethrow;
    }
  }

  Future<List<String>> getFreeRooms({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    String y = date.year.toString();
    String m = date.month < 10 ? '0${date.month}' : date.month.toString();
    String d = date.day < 10 ? '0${date.day}' : date.day.toString();
    String formattedDate = '$y-$m-$d';

    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/classrooms/free',
        queryParameters: {
          'date': formattedDate,
          'start_time': startTime,
          'end_time': endTime,
        },
      );

      if (response.statusCode == 200) {
        return List<String>.from(response.data);
      } else {
        throw Exception("Ошибка при запросе свободных аудиторий");
      }
    } catch (e) {
      rethrow;
    }
  }

  List<ScheduleEventsCompanion> _mapModelToCompanions(
    WeekScheduleModel weekSchedule,
    String groupName,
  ) {
    List<ScheduleEventsCompanion> companions = [];

    for (int i = 0; i < weekSchedule.lessonModel.length; i++) {
      var day = weekSchedule.lessonModel[i];

      for (int j = 0; j < day.lessons.length; j++) {
        var lesson = day.lessons[j];
        var teachersList = [Teacher(fio: lesson.name)];

        companions.add(
          ScheduleEventsCompanion.insert(
            date: day.date,
            dayWeek: day.dayWeek,
            startTime: lesson.startTime,
            endTime: lesson.endTime,
            numberPair: lesson.numberPair,
            discipline: lesson.discipline,
            groupType: Value(lesson.lessonType.russian),
            classroom: Value(lesson.classroom),
            groupName: groupName,
            teachers: teachersList,
          ),
        );
      }
    }
    return companions;
  }

  WeekScheduleModel _mapDbToModel(List<ScheduleDbEntity> dbEvents) {
    Map<String, List<ScheduleDbEntity>> groupedByDate = {};
    for (int i = 0; i < dbEvents.length; i++) {
      var event = dbEvents[i];
      if (groupedByDate[event.date] == null) {
        groupedByDate[event.date] = [];
      }
      groupedByDate[event.date]!.add(event);
    }

    List<DayScheduleModel> days = [];

    groupedByDate.forEach((date, events) {
      List<LessonModel> lessons = [];

      for (int i = 0; i < events.length; i++) {
        var e = events[i];
        String teacherName = 'Преподаватель не указан';
        if (e.teachers.isNotEmpty && e.teachers[0].fio != null) {
          teacherName = e.teachers[0].fio!;
        }

        lessons.add(
          LessonModel(
            name: teacherName,
            classroom: e.classroom ?? 'Универ',
            lessonType:
                LessonType.fromString(e.groupType ?? '') ?? LessonType.other,
            endTime: e.endTime,
            startTime: e.startTime,
            discipline: e.discipline,
            numberPair: e.numberPair,
          ),
        );
      }

      days.add(
        DayScheduleModel(
          lessons: lessons,
          date: date,
          dayWeek: events[0].dayWeek,
          len: lessons.length,
        ),
      );
    });

    return WeekScheduleModel(lessonModel: days, days: days.length);
  }
}
