import 'dart:async';

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
  for (final target in [null, '', 'B']) {
    for (final fails in [false, true]) {
      testWidgets(
        'group A to $target discards late ${fails ? 'error' : 'success'}',
        (tester) async {
          final auth = MockAuthBloc();
          final changes = StreamController<AuthState>.broadcast();
          AuthAuthenticated signedIn(String? group) => AuthAuthenticated(
            profileModel: ProfileModel(
              registrationProfileData: RegistrationProfileData(
                displayName: 'Alice',
                avatarEmoji: '😀',
                groupCode: group,
              ),
              userModel: const UserModel(id: 'user', email: 'a@b.co'),
            ),
          );
          AuthState state = signedIn('A');
          when(() => auth.state).thenAnswer((_) => state);
          when(() => auth.stream).thenAnswer((_) => changes.stream);
          final repo = MockScheduleRepository();
          final pending = Completer<WeekScheduleModel>();
          final today = DateTime.now();
          final date =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          WeekScheduleModel week(String discipline) => WeekScheduleModel(
            days: 1,
            lessonModel: [
              DayScheduleModel(
                date: date,
                dayWeek: 'Monday',
                len: 1,
                lessons: [
                  LessonModel(
                    name: 'Teacher',
                    classroom: '101',
                    lessonType: LessonType.lecture,
                    startTime: '09:00',
                    endTime: '10:30',
                    discipline: discipline,
                    numberPair: 1,
                  ),
                ],
              ),
            ],
          );
          when(
            () => repo.getSchedule('A', 0),
          ).thenAnswer((_) => pending.future);
          when(
            () => repo.getSchedule('B', 0),
          ).thenAnswer((_) async => week('NEW GROUP'));
          final bloc = ScheduleBloc(scheduleRepository: repo);
          await tester.pumpWidget(
            MaterialApp(
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<AuthBloc>.value(value: auth),
                  BlocProvider.value(value: bloc),
                ],
                child: const Scaffold(body: ScheduleScreen()),
              ),
            ),
          );
          await tester.pump();
          state = signedIn(target);
          changes.add(state);
          await tester.pumpAndSettle();
          if (fails) {
            pending.completeError(Exception('OLD ERROR'));
          } else {
            pending.complete(week('OLD GROUP'));
          }
          await tester.pumpAndSettle();
          expect(find.text('OLD GROUP'), findsNothing);
          expect(find.textContaining('OLD ERROR'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          if (target == 'B') {
            expect(find.text('NEW GROUP'), findsOneWidget);
          } else {
            expect(find.text('Укажите группу в профиле'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(bloc.close);
          await changes.close();
        },
      );
    }
  }
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
