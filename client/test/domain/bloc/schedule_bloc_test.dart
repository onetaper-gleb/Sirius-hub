import 'dart:async';

import 'package:client/data/repository/schedule_repository.dart';
import 'package:client/domain/bloc/schedule/schedule_bloc.dart';
import 'package:client/domain/bloc/schedule/schedule_event.dart';
import 'package:client/domain/bloc/schedule/schedule_state.dart';
import 'package:client/domain/model/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements ScheduleRepository {}

void main() {
  test(
    'late responses cannot replace the newly selected group or week',
    () async {
      final repository = MockRepository();
      final first = Completer<WeekScheduleModel>();
      final second = Completer<WeekScheduleModel>();
      when(
        () => repository.getSchedule('A', 0),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.getSchedule('B', 1),
      ).thenAnswer((_) => second.future);
      final bloc = ScheduleBloc(scheduleRepository: repository);
      bloc.add(ScheduleGetWeek(group: 'A', weekOffset: 0));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ScheduleGetWeek(group: 'B', weekOffset: 1));
      await Future<void>.delayed(Duration.zero);
      final newerWeek = WeekScheduleModel(days: 0, lessonModel: []);
      final loaded = bloc.stream.firstWhere((s) => s is ScheduleHasWeek);
      second.complete(newerWeek);
      await loaded;
      first.complete(WeekScheduleModel(days: 1, lessonModel: []));
      await Future<void>.delayed(Duration.zero);
      expect((bloc.state as ScheduleHasWeek).week, same(newerWeek));
      await bloc.close();
    },
  );
}
