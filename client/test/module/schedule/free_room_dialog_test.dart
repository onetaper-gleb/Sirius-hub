import 'package:client/data/repository/schedule_repository.dart';
import 'package:client/domain/bloc/schedule/schedule_bloc.dart';
import 'package:client/domain/bloc/schedule/schedule_event.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/module/schedule/widgets/free_room_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements ScheduleRepository {}

void main() {
  testWidgets(
    'free-room dialog has seven days on a narrow display and leaves the week bloc unchanged',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MockRepository();
      final week = WeekScheduleModel(days: 0, lessonModel: []);
      when(() => repo.getSchedule('A', 0)).thenAnswer((_) async => week);
      final parent = ScheduleBloc(scheduleRepository: repo);
      final loaded = parent.stream.first;
      parent.add(ScheduleGetWeek(group: 'A', weekOffset: 0));
      await tester.pump();
      await loaded;
      await tester.pump();
      final before = parent.state;
      final dialogBloc = ScheduleBloc(scheduleRepository: repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: dialogBloc,
              child: const FreeRoomDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Вс'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(dialogBloc.close);
      expect(parent.state, same(before));
      await tester.runAsync(parent.close);
    },
  );
}
