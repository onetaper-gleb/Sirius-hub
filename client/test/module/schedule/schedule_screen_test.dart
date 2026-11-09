import 'package:client/data/repository/schedule_repository.dart';
import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/bloc/schedule/schedule_bloc.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/domain/model/profile_model.dart';
import 'package:client/module/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

class MockScheduleRepository extends Mock implements ScheduleRepository {}

void main() {
  for (final hasLessons in [false, true]) {
    testWidgets(
      'schedule layout supports ${hasLessons ? 'lessons' : 'an empty day'}',
      (tester) async {
        final auth = MockAuthBloc();
        final repo = MockScheduleRepository();
        final today = DateTime.now();
        final day = today;
        final date =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final week = WeekScheduleModel(
          days: 1,
          lessonModel: [
            DayScheduleModel(
              date: date,
              dayWeek: 'Monday',
              len: hasLessons ? 1 : 0,
              lessons: hasLessons
                  ? [
                      const LessonModel(
                        name: 'Teacher',
                        classroom: '101',
                        lessonType: LessonType.lecture,
                        endTime: '10:30',
                        startTime: '09:00',
                        discipline: 'Physics',
                        numberPair: 1,
                      ),
                    ]
                  : [],
            ),
          ],
        );
        when(() => auth.state).thenReturn(
          AuthAuthenticated(
            profileModel: ProfileModel(
              registrationProfileData: const RegistrationProfileData(
                displayName: 'Alice',
                avatarEmoji: '😀',
                groupCode: 'Group A',
              ),
              userModel: const UserModel(id: 'user', email: 'a@b.co'),
            ),
          ),
        );
        when(() => auth.stream).thenAnswer((_) => const Stream.empty());
        when(
          () => repo.getSchedule('Group A', 0),
        ).thenAnswer((_) async => week);
        final schedule = ScheduleBloc(scheduleRepository: repo);
        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: auth),
                BlocProvider.value(value: schedule),
              ],
              child: const Scaffold(body: ScheduleScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(hasLessons ? 'Physics' : 'На этот день пар нет!'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(schedule.close);
      },
    );
  }
}
