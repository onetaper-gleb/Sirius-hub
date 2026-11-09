import 'package:client/data/local/app_database.dart';
import 'package:client/data/local/local_settings.dart';
import 'package:client/data/repository/schedule_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';

String isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late LocalSettings settings;
  late Dio dio;
  late ScheduleRepository repo;
  var networkRequests = 0;
  var offline = false;
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day - today.weekday + 1,
  );

  Future<void> cache(String group, DateTime date) => db.insertSchedule([
    ScheduleEventsCompanion.insert(
      date: isoDate(date),
      dayWeek: 'Monday',
      startTime: '09:00',
      endTime: '10:30',
      numberPair: 1,
      discipline: 'Cached $group',
      groupName: group,
      teachers: [],
    ),
  ]);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = LocalSettings(await SharedPreferences.getInstance());
    db = AppDatabase.forTesting(NativeDatabase.memory());
    networkRequests = 0;
    offline = false;
    dio = Dio();
    dio.httpClientAdapter = FakeApi((request) async {
      networkRequests++;
      if (offline)
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'Offline',
        );
      return FakeApi.json([
        {
          'date': isoDate(monday),
          'day_week': 'Monday',
          'events': [
            {
              'start_time': '09:00',
              'end_time': '10:30',
              'number_pair': 1,
              'discipline': 'Network',
              'teachers': [],
              'classroom': '101',
            },
          ],
        },
      ]);
    });
    repo = ScheduleRepository(dio: dio, db: db, localSettings: settings);
  });
  tearDown(() => db.close());

  test('current-week cache remains available offline', () async {
    await cache('A', monday);
    offline = true;
    final result = await repo.getSchedule('A', 0);
    expect(result.lessonModel.single.lessons.single.discipline, 'Cached A');
  });

  test('last-week rows never masquerade as the current week offline', () async {
    await cache('A', monday.subtract(const Duration(days: 7)));
    await settings.saveLastSyncTime('A', DateTime.now().millisecondsSinceEpoch);
    offline = true;
    await expectLater(repo.getSchedule('A', 0), throwsA(isA<DioException>()));
    expect(networkRequests, 1);
  });

  test(
    'syncing one group does not make a different group cache fresh',
    () async {
      await cache('A', monday);
      await settings.saveLastSyncTime(
        'B',
        DateTime.now().millisecondsSinceEpoch,
      );
      final result = await repo.getSchedule('A', 0);
      expect(result.lessonModel.single.lessons.single.discipline, 'Network');
      expect(networkRequests, 1);
      expect(settings.getLastSyncTime('A'), isNotNull);
    },
  );

  test('fresh current-week data avoids another request', () async {
    await cache('A', monday);
    await settings.saveLastSyncTime('A', DateTime.now().millisecondsSinceEpoch);
    final result = await repo.getSchedule('A', 0);
    expect(result.lessonModel.single.lessons.single.discipline, 'Cached A');
    expect(networkRequests, 0);
  });
}
