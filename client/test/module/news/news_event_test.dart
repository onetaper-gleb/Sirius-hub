import 'dart:async';

import 'package:client/data/repository/news_repository.dart';
import 'package:client/domain/bloc/news/news_bloc.dart';
import 'package:client/domain/bloc/news/news_event.dart';
import 'package:client/domain/bloc/news/news_state.dart';
import 'package:client/domain/model/model.dart';
import 'package:client/module/news/news_detail_screen.dart';
import 'package:client/module/news/create_news_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements NewsRepository {}

class MockNewsBloc extends Mock implements NewsBloc {}

class FakeNewsEvent extends Fake implements NewsEvent {}

final news = NewsModel(
  id: 'news',
  title: 'Title',
  content: 'Content',
  authorId: 'author',
  createdAt: DateTime(2026),
  hasEvent: true,
  eventId: 'event',
  hasTopic: false,
  anon: false,
);
final event = EventModel(
  id: 'event',
  status: EventStatus.published,
  newsId: 'news',
  eventStart: '2026-11-09',
  eventEnd: '2026-11-10',
  location: 'Campus',
  maxParticipants: 50,
  currentParticipants: 3,
  isRegOpen: true,
);

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNewsEvent());
  });

  for (final dismissal in ['confirm', 'cancel', 'barrier']) {
    testWidgets('registration dialog safely disposes after $dismissal', (
      tester,
    ) async {
      final repo = MockRepository();
      when(() => repo.getEvent('event')).thenAnswer((_) async => event);
      when(
        () => repo.registerForEvent(eventId: 'event', comment: 'Hello'),
      ).thenAnswer(
        (_) async => RegistrationModel(
          id: 'registration',
          eventId: 'event',
          userId: 'user',
          status: 'registered',
        ),
      );
      final bloc = NewsBloc(newsRepository: repo);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: NewsDetailScreen(news: news),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      if (dismissal == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(
          find.text(dismissal == 'confirm' ? 'Записаться' : 'Отмена'),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      if (dismissal == 'confirm') {
        verify(
          () => repo.registerForEvent(eventId: 'event', comment: 'Hello'),
        ).called(1);
      } else {
        verifyNever(
          () => repo.registerForEvent(
            eventId: 'event',
            comment: any(named: 'comment'),
          ),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    });
  }

  for (final unit in ['a', '😀', 'e\u0301']) {
    testWidgets(
      'registration validates 50 code points without truncating $unit',
      (tester) async {
        final repo = MockRepository();
        when(() => repo.getEvent('event')).thenAnswer((_) async => event);
        final boundary = List.filled(50 ~/ unit.runes.length, unit).join();
        final tooLong = '$boundary$unit';
        when(
          () => repo.registerForEvent(eventId: 'event', comment: boundary),
        ).thenAnswer(
          (_) async => RegistrationModel(
            id: 'registration',
            eventId: 'event',
            userId: 'user',
            status: 'registered',
          ),
        );
        final bloc = NewsBloc(newsRepository: repo);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: bloc,
              child: NewsDetailScreen(news: news),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Зарегистрироваться'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), tooLong);
        await tester.tap(find.text('Записаться'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          tooLong,
        );
        verifyNever(
          () => repo.registerForEvent(
            eventId: 'event',
            comment: any(named: 'comment'),
          ),
        );
        await tester.enterText(find.byType(TextField), boundary);
        await tester.tap(find.text('Записаться'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        verify(
          () => repo.registerForEvent(eventId: 'event', comment: boundary),
        ).called(1);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(bloc.close);
      },
    );
  }

  testWidgets(
    'event details render loading then data without a null assertion',
    (tester) async {
      final repo = MockRepository();
      final pending = Completer<EventModel>();
      when(() => repo.getEvent('event')).thenAnswer((_) => pending.future);
      final bloc = NewsBloc(newsRepository: repo);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: NewsDetailScreen(news: news),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(event);
      await tester.pumpAndSettle();
      expect(find.text('Campus'), findsOneWidget);
      expect(find.text('Участников: 3/50'), findsOneWidget);
      expect(find.text('Зарегистрироваться'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(bloc.close);
    },
  );

  testWidgets('failed event fetch exposes a working retry', (tester) async {
    final repo = MockRepository();
    var attempts = 0;
    when(() => repo.getEvent('event')).thenAnswer((_) async {
      if (++attempts == 1) throw Exception('Offline');
      return event;
    });
    final bloc = NewsBloc(newsRepository: repo);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: NewsDetailScreen(news: news),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Campus'), findsOneWidget);
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(bloc.close);
  });

  testWidgets('creating an event sends the validated participant capacity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = MockNewsBloc();
    when(() => bloc.state).thenReturn(NewsInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NewsBloc>.value(
          value: bloc,
          child: const CreateNewsScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Title');
    await tester.enterText(find.byType(TextField).at(1), 'Content');
    await tester.tap(find.text('Добавить событие'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '2026-11-09');
    await tester.enterText(fields.at(3), '2026-11-10');
    await tester.enterText(fields.at(4), 'Campus');
    await tester.enterText(fields.at(5), '50');
    await tester.tap(find.byType(DropdownButtonFormField<EventStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовано').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    verify(
      () => bloc.add(
        any(
          that: isA<CreateNews>().having(
            (e) => e.maxParticipants,
            'maxParticipants',
            50,
          ),
        ),
      ),
    ).called(1);
    await tester.pumpWidget(const SizedBox());
  });

  test('event registration parses the API user_id field', () {
    expect(
      RegistrationModel.fromJson({
        'id': 'reg',
        'event_id': 'event',
        'user_id': 'user',
        'status': 'registered',
      }).userId,
      'user',
    );
  });
}
