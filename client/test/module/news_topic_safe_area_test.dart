import 'package:client/domain/model/news_model.dart';
import 'package:client/module/forum/forum_screen.dart';
import 'package:client/module/forum/topic_screen.dart';
import 'package:client/module/news/create_news_screen.dart';
import 'package:client/module/news/news_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_routes_test.dart' as fixtures;

Future<void> setInsets(WidgetTester tester, {double keyboard = 0}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.viewPadding = const FakeViewPadding(
    top: 44,
    bottom: 34,
    left: 12,
    right: 12,
  );
  tester.view.padding = FakeViewPadding(
    top: 44,
    bottom: keyboard == 0 ? 34 : 0,
    left: 12,
    right: 12,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  await tester.pumpAndSettle();
}

void resetInsets(WidgetTester tester) {
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewInsets);
}

void main() {
  for (final keyboard in [0.0, 300.0]) {
    testWidgets('news form remains scrollable above bottom inset $keyboard', (
      tester,
    ) async {
      final h = fixtures.AccountHarness();
      await h.pump(tester);
      resetInsets(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(CreateNewsScreen), findsOneWidget);
      await setInsets(tester, keyboard: keyboard);
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.pumpAndSettle();
      final save = tester.getRect(find.text('Сохранить'));
      expect(
        save.bottom,
        lessThanOrEqualTo(800 - (keyboard == 0 ? 34 : keyboard)),
      );
      expect(save.left, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });

    testWidgets('topic composer stays directly above inset $keyboard', (
      tester,
    ) async {
      final h = fixtures.AccountHarness();
      h.items.add(
        NewsModel.fromJson({
          'id': 'news',
          'title': 'Private title',
          'content': List.filled(80, 'News content').join('\n'),
          'author_id': 'author',
          'created_at': '2026-11-09',
          'has_topic': true,
          'topic_id': 'topic',
        }),
      );
      await h.pump(tester);
      resetInsets(tester);
      await tester.tap(find.text('Private title'));
      await tester.pumpAndSettle();
      expect(find.byType(NewsDetailScreen), findsOneWidget);
      await setInsets(tester);
      final detailViewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(detailViewport.bottom, 766);
      expect(detailViewport.top, tester.getRect(find.byType(AppBar)).bottom);
      await tester.ensureVisible(find.text('Прокомментировать'));
      await tester.tap(find.text('Прокомментировать'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicScreen), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await setInsets(tester, keyboard: keyboard);
      final input = tester.getRect(find.byType(TextField));
      final boundary = 800 - (keyboard == 0 ? 34 : keyboard);
      expect(input.bottom, lessThanOrEqualTo(boundary));
      expect(boundary - input.bottom, lessThan(30));
      expect(input.left, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });

    testWidgets('topic creation sheet stays reachable with inset $keyboard', (
      tester,
    ) async {
      final h = fixtures.AccountHarness();
      await h.pump(tester);
      resetInsets(tester);
      await tester.tap(find.text('Форум').last);
      await tester.pumpAndSettle();
      expect(find.byType(ForumScreen), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await setInsets(tester, keyboard: keyboard);
      await tester.ensureVisible(find.text('Создать'));
      await tester.pumpAndSettle();
      final create = tester.getRect(find.text('Создать'));
      expect(
        create.bottom,
        lessThanOrEqualTo(800 - (keyboard == 0 ? 34 : keyboard)),
      );
      expect(
        tester.getTopLeft(find.text('Новый топик')).dy,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }
}
