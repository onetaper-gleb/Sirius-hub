import 'package:client/data/repository/news_repository.dart';
import 'package:client/data/source/source.dart';
import 'package:client/domain/bloc/news/news_bloc.dart';
import 'package:client/domain/bloc/news/news_state.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/module/news/create_news_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/json_api.dart';

class CreateSource extends Mock implements AuthDataSource {}

class CreateHarness {
  late final JsonApi api;
  late final NewsBloc bloc;
  final items = <Map<String, dynamic>>[];

  CreateHarness() {
    final source = CreateSource();
    when(() => source.getToken()).thenAnswer((_) async => 'token');
    api = JsonApi((request, body) {
      if (request.method == 'POST') {
        final item = <String, dynamic>{
          ...body!,
          'id': 'news',
          'event_id': body['has_event'] == true ? 'event' : null,
        };
        items.add(item);
        return item;
      }
      return items;
    });
    bloc = NewsBloc(
      newsRepository: NewsRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://example.test/'))
          ..httpClientAdapter = api,
        authDataSource: source,
      ),
    );
  }

  List<Map<String, dynamic>> get creations => [
    for (final (request, body) in api.requests)
      if (request.method == 'POST') body!,
  ];

  Future<void> pump(
    WidgetTester tester, {
    bool event = false,
    bool topic = false,
    String title = 'Event',
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateNewsScreen(),
                      ),
                    ),
                    child: const Text('Create'),
                  ),
                  BlocBuilder<NewsBloc, NewsState>(
                    builder: (_, state) => Text(
                      state is NewsLoaded
                          ? 'Feed: ${state.newsList.single.title}'
                          : 'Empty',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Заголовок'), title);
    await tester.enterText(input('Текст новости'), 'Body');
    if (topic) {
      await tester.tap(find.text('Добавить обсуждение'));
      await tester.pumpAndSettle();
    }
    if (event) {
      await tester.tap(find.text('Добавить событие'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input('Дата начала')).decoration!.hintText,
        'дд.мм.гггг',
      );
      expect(
        tester.widget<TextField>(input('Дата окончания')).decoration!.hintText,
        'дд.мм.гггг',
      );
      await tester.enterText(input('Место проведения'), 'Campus');
      await tester.enterText(input('Макс. кол-во участников'), '50');
      await tester.tap(find.byType(DropdownButtonFormField<EventStatus>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Опубликовано').last);
      await tester.pumpAndSettle();
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(bloc.close);
  }
}

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  for (final (start, end, isoStart, isoEnd) in [
    (
      '09.11.2026',
      '10.11.2026',
      '2026-11-09T00:00:00.000',
      '2026-11-10T00:00:00.000',
    ),
    (
      '29.02.2028',
      '01.03.2028',
      '2028-02-29T00:00:00.000',
      '2028-03-01T00:00:00.000',
    ),
  ]) {
    testWidgets(
      'shown dates $start/$end become ISO through real bloc and serialized request',
      (tester) async {
        final h = CreateHarness();
        await h.pump(tester, event: true, topic: true);
        await tester.enterText(input('Дата начала'), start);
        await tester.enterText(input('Дата окончания'), end);
        await h.submit(tester);
        expect(tester.takeException(), isNull);
        expect(h.creations, hasLength(1));
        expect(h.creations.single, containsPair('event_start', isoStart));
        expect(h.creations.single, containsPair('event_end', isoEnd));
        expect(h.creations.single, containsPair('has_event', true));
        expect(h.creations.single, containsPair('has_topic', true));
        expect(find.byType(CreateNewsScreen), findsNothing);
        expect(find.text('Feed: Event'), findsOneWidget);
        await h.close(tester);
      },
    );
  }
  for (final (start, end, error) in [
    (
      '31.02.2026',
      '10.03.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '29.02.2026',
      '01.03.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '31.04.2026',
      '01.05.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '00.11.2026',
      '10.11.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '09.13.2026',
      '10.11.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '09.11.0000',
      '10.11.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '2026-11-09',
      '10.11.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '9.11.2026',
      '10.11.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '09.11.2026',
      '31.11.2026',
      'Укажите существующие даты в формате дд.мм.гггг',
    ),
    (
      '09.11.2026',
      '09.11.2026',
      'Дата окончания должна быть позже даты начала',
    ),
    (
      '10.11.2026',
      '09.11.2026',
      'Дата окончания должна быть позже даты начала',
    ),
  ]) {
    testWidgets(
      'invalid event dates $start/$end preserve input and do not send',
      (tester) async {
        final h = CreateHarness();
        await h.pump(tester, event: true);
        await tester.enterText(input('Дата начала'), start);
        await tester.enterText(input('Дата окончания'), end);
        await h.submit(tester);
        expect(h.creations, isEmpty);
        expect(find.text(error), findsOneWidget);
        expect(
          tester.widget<TextField>(input('Дата начала')).controller!.text,
          start,
        );
        expect(
          tester.widget<TextField>(input('Дата окончания')).controller!.text,
          end,
        );
        expect(tester.takeException(), isNull);
        await h.close(tester);
      },
    );
  }
  for (final topic in [false, true]) {
    for (final title in ['Я', '${'a' * 59}😀', '${'a' * 60}😀']) {
      testWidgets(
        'news topic=$topic title ${title.runes.length} uses shared bound60',
        (tester) async {
          final h = CreateHarness();
          await h.pump(tester, topic: topic, title: title);
          expect(
            tester.widget<TextField>(input('Заголовок')).controller!.text,
            title,
          );
          await h.submit(tester);
          if (title.runes.length > 60) {
            expect(h.creations, isEmpty);
            expect(
              find.text('Заголовок — не длиннее 60 символов'),
              findsOneWidget,
            );
            expect(
              tester.widget<TextField>(input('Заголовок')).controller!.text,
              title,
            );
          } else {
            expect(h.creations.single['title'], title);
            expect(find.text('Feed: $title'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await h.close(tester);
        },
      );
    }
  }
}
