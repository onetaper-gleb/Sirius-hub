import 'package:client/domain/bloc/auth/auth_bloc.dart';
import 'package:client/domain/bloc/auth/auth_state.dart';
import 'package:client/domain/bloc/schedule/schedule_bloc.dart';
import 'package:client/domain/bloc/schedule/schedule_state.dart';
import 'package:flutter/material.dart';
import 'package:client/domain/model/model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/bloc/schedule/schedule_event.dart';
import '../../domain/model/schedule_models/lesson_group.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Local variables
  WeekScheduleModel? _weekScheduleModel;
  Map<int, WeekScheduleModel> _history = {};
  int _currentWeek = 0;
  late int _currentDay;
  int _selectedDay = 0;
  String? _group;
  late List<DateTime> _days;
  final List<String> _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  // Overrides
  @override
  void initState() {
    super.initState();
    _days = _getWeekDays();
    final weekday = DateTime.now().weekday;
    _currentDay = (weekday >= 1 && weekday <= 6) ? weekday - 1 : 0;
    _selectedDay = _currentDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final groupCode =
          authState.profileModel.registrationProfileData.groupCode;
      if (groupCode != null && _group == null) {
        _currentWeek = 0;
        _group = groupCode;
        _getWeek();
      }
    }
  }

  // Functions
  void _updateWeek(String method) {
    if (_group == null) return;
    final currentState = context.read<ScheduleBloc>().state;
    if (currentState is SchedulePending) return;
    switch (method) {
      case 'nextWeek':
        _currentWeek += 1;
      case 'previousWeek':
        _currentWeek -= 1;
    }
    print('_currentWeek: $_currentWeek');
    if (_history.containsKey(_currentWeek)) {
      _days = _getWeekDays();
      setState(() {
        _weekScheduleModel = _history[_currentWeek]!;
        _currentWeek = _currentWeek;
      });
    } else {
      _getWeek();
    }
  }

  void _getWeek() {
    context.read<ScheduleBloc>().add(
      ScheduleGetWeek(weekOffset: _currentWeek, group: _group!),
    );
  }

  List<DateTime> _getWeekDays() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final targetMonday = monday.add(Duration(days: _currentWeek * 7));
    print('monday: ${monday}, targetMonday: ${targetMonday}');
    return List.generate(6, (index) => targetMonday.add(Duration(days: index)));
  }

  // Widgets
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          final groupCode =
              state.profileModel.registrationProfileData.groupCode;
          if (groupCode != null) {
            _group = groupCode;
            _currentWeek = 0;
            _getWeek();
          }
        }
      },
      child: BlocConsumer<ScheduleBloc, ScheduleState>(
        listener: (context, state) {
          if (state is ScheduleHasWeek) {
            setState(() {
              _days = _getWeekDays();
              _weekScheduleModel = state.week;
              _history[_currentWeek] = state.week;
            });
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                _buildWeekHeader(),
                if (_group == null && state is ScheduleInitial)
                  Center(child: Text('Укажите группу в профиле')),
                if (state is SchedulePending)
                  Center(child: CircularProgressIndicator()),
                if (state is ScheduleHasWeek && _weekScheduleModel != null)
                  _buildScheduleToday(),
                if (state is ScheduleError) Text(state.error.toString()),
              ],
            ),
          );
        },
      ),
    );
  }

  // Виджет верхней панели
  Widget _buildWeekHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _updateWeek('previousWeek'),
          ),
          Expanded(
            child: SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  return _buildDayItem(index);
                },
              ),
            ),
          ),
          _buildArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => _updateWeek('nextWeek'),
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(int index) {
    final isToday = index == _currentDay && _currentWeek == 0;
    final isSelected = index == _selectedDay;
    final day = _days[index];

    Color circleColor;
    Color circleBorder;
    Color dayNumColor;
    Color dayNameColor;
    FontWeight dayNumWeight;

    if (isSelected && isToday) {
      circleColor = Colors.blue;
      circleBorder = Colors.blue;
      dayNumColor = Colors.white;
      dayNameColor = Colors.blue;
      dayNumWeight = FontWeight.bold;
    } else if (isSelected) {
      circleColor = Colors.blue.withOpacity(0.15);
      circleBorder = Colors.blue;
      dayNumColor = Colors.blue;
      dayNameColor = Colors.blue;
      dayNumWeight = FontWeight.bold;
    } else if (isToday) {
      circleColor = Colors.transparent;
      circleBorder = Colors.blue.withOpacity(0.5);
      dayNumColor = Colors.blue;
      dayNameColor = Colors.blue.withOpacity(0.7);
      dayNumWeight = FontWeight.w600;
    } else {
      circleColor = Colors.transparent;
      circleBorder = Colors.transparent;
      dayNumColor = Colors.grey.shade700;
      dayNameColor = Colors.grey.shade500;
      dayNumWeight = FontWeight.normal;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = index),
      // ✅ opaque — вся область контейнера реагирует на тап,
      // даже если она прозрачная
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        // ✅ SizedBox вместо Container — вся высота ListView (72px)
        // становится кликабельной зоной, а не только кружок+текст
        width: (MediaQuery.of(context).size.width - 88) / 6,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor,
                border: Border.all(color: circleBorder, width: 1.5),
              ),
              child: Center(
                child: Text(
                  day.day.toString(),
                  style: TextStyle(
                    color: dayNumColor,
                    fontWeight: dayNumWeight,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dayNames[index],
              style: TextStyle(
                color: dayNameColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isLoading = context.read<ScheduleBloc>().state is SchedulePending;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      // ✅ opaque — область вокруг иконки тоже реагирует
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // ✅ Padding увеличивает область нажатия вокруг иконки
        // без изменения визуального размера кнопки
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        child: Icon(
          icon,
          color: isLoading ? Colors.grey : Colors.blue,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildScheduleToday() {
    final day = _weekScheduleModel!.lessonModel[_selectedDay];
    final groups = _groupLessons(day);
    final breaks = _calculateBreaksFromGroups(groups);

    // Строим плоский список: группа, перерыв, группа, перерыв...
    final items = <dynamic>[];
    for (int i = 0; i < groups.length; i++) {
      items.add(groups[i]);
      if (i < breaks.length) items.add(breaks[i]);
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.separated(
          key: ValueKey('$_selectedDay-$_currentWeek'),
          padding: const EdgeInsets.symmetric(vertical: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is LessonGroupModel) return _buildLessonGroup(item);
            if (item is BreakModel) return _buildBreakCard(item);
            return const SizedBox();
          },
        ),
      ),
    );
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  List<BreakModel> _calculateBreaksFromGroups(List<LessonGroupModel> groups) {
    final breaks = <BreakModel>[];

    for (int i = 0; i < groups.length - 1; i++) {
      final currentEnd = _parseTime(groups[i].endTime);
      final nextStart = _parseTime(groups[i + 1].startTime);
      final minutes = nextStart.difference(currentEnd).inMinutes;

      if (minutes <= 0) continue;

      breaks.add(
        BreakModel(
          type: _defineBreakType(
            startTime: currentEnd,
            endTime: nextStart,
            durationMinutes: minutes,
          ),
          startTime: groups[i].endTime,
          endTime: groups[i + 1].startTime,
        ),
      );
    }

    return breaks;
  }

  Widget _buildLessonCard(int number, LessonModel lesson) {
    final color = lesson.lessonType.color;
    final bgColor = color.withOpacity(0.06);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Цветная полоса слева
            Container(width: 4, color: color),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Шапка: тип + время
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Бейдж типа занятия
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: color.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            lesson.lessonType.displayName,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Время
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${lesson.startTime} – ${lesson.endTime}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Название дисциплины
                    Text(
                      lesson.discipline,
                      style: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),
                    Divider(color: color.withOpacity(0.15), height: 1),
                    const SizedBox(height: 10),

                    // Преподаватель
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                          color: color.withOpacity(0.7),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            lesson.name,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Аудитория
                    Row(
                      children: [
                        Icon(
                          Icons.room_outlined,
                          size: 15,
                          color: color.withOpacity(0.7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          lesson.classroom,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonGroup(LessonGroupModel group) {
    if (group.lessons.length == 1) {
      return _buildLessonCard(group.numberPair, group.lessons.first);
    }

    // Несколько пар в одно время — показываем как вкладки
    return _buildMultipleLessonsCard(group);
  }

  Widget _buildMultipleLessonsCard(LessonGroupModel group) {
    final groupColor = group.lessons.first.lessonType.color;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: groupColor),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок группы
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(Icons.call_split_rounded, size: 15, color: groupColor),
                const SizedBox(width: 6),
                Text(
                  'Параллельные занятия',
                  style: TextStyle(
                    color: groupColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${group.startTime} – ${group.endTime}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: groupColor, height: 1),

          // Каждая пара
          ...group.lessons.asMap().entries.map((entry) {
            final i = entry.key;
            final lesson = entry.value;
            final color = lesson.lessonType.color;

            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Тип
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: color.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  lesson.lessonType.displayName,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Дисциплина
                              Text(
                                lesson.discipline,
                                style: const TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Преподаватель
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 13,
                                    color: color.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      lesson.name,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Аудитория
                              Row(
                                children: [
                                  Icon(
                                    Icons.room_outlined,
                                    size: 13,
                                    color: color.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    lesson.classroom,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < group.lessons.length - 1)
                  Divider(color: groupColor, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  BreakType _defineBreakType({
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
  }) {
    // Промежуток обеда: 12:00 - 15:00
    final lunchStart = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      12,
      0,
    );
    final lunchEnd = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      15,
      0,
    );

    final overlapsLunch =
        startTime.isBefore(lunchEnd) && endTime.isAfter(lunchStart);

    if (durationMinutes > 20 && overlapsLunch) {
      return BreakType.lunch;
    } else if (durationMinutes > 20) {
      return BreakType.window;
    } else {
      return BreakType.rest;
    }
  }

  Widget _buildBreakCard(BreakModel breakModel) {
    final (
      Color bgColor,
      Color borderColor,
      Color iconColor,
      IconData icon,
    ) = switch (breakModel.type) {
      BreakType.lunch => (
        Colors.orange.withOpacity(0.07),
        Colors.orange.withOpacity(0.3),
        Colors.orange.shade700,
        Icons.restaurant_rounded,
      ),
      BreakType.window => (
        Colors.purple.withOpacity(0.07),
        Colors.purple.withOpacity(0.3),
        Colors.purple.shade700,
        Icons.access_time_rounded,
      ),
      BreakType.rest => (
        Colors.blue.withOpacity(0.07),
        Colors.blue.withOpacity(0.3),
        Colors.blue.shade700,
        Icons.coffee_rounded,
      ),
    };

    final start = _parseTime(breakModel.startTime);
    final end = _parseTime(breakModel.endTime);
    final duration = end.difference(start).inMinutes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                breakModel.type.russian,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${breakModel.startTime} – ${breakModel.endTime} · $duration мин',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<LessonGroupModel> _groupLessons(DayScheduleModel day) {
    final groups = <LessonGroupModel>[];
    final lessons = day.lessons;

    int i = 0;
    while (i < lessons.length) {
      final current = lessons[i];
      final same = <LessonModel>[current];

      // Собираем все пары с одинаковым временем
      while (i + 1 < lessons.length &&
          lessons[i + 1].startTime == current.startTime &&
          lessons[i + 1].endTime == current.endTime) {
        i++;
        same.add(lessons[i]);
      }

      groups.add(
        LessonGroupModel(
          startTime: current.startTime,
          endTime: current.endTime,
          numberPair: current.numberPair,
          lessons: same,
        ),
      );
      i++;
    }

    return groups;
  }
}
