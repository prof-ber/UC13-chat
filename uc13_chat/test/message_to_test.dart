import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uc13_chat/components/message.dart';

void main() {
  group('MessageWidget Tests', () {
    testWidgets('MessageWidget renders correctly for "from" direction', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              name: 'João',
              message: 'Olá!',
              direction: MessageDirection.from,
            ),
          ),
        ),
      );

      expect(find.text('João'), findsOneWidget);
      expect(find.text('Olá!'), findsOneWidget);

      final messageFinder = find.byType(MessageWidget);
      expect(messageFinder, findsOneWidget);

      final messageWidget = tester.widget<MessageWidget>(messageFinder);
      expect(messageWidget.direction, MessageDirection.from);

      final containerFinder = find.descendant(
        of: messageFinder,
        matching: find.byWidgetPredicate((widget) => widget is Container),
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.amberAccent);
      expect(decoration.borderRadius, const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ));
      expect(container.margin, const EdgeInsets.fromLTRB(100, 10, 10, 10));
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 20, vertical: 15));

      final columnFinder = find.descendant(
        of: containerFinder,
        matching: find.byType(Column),
      );
      expect(columnFinder, findsOneWidget);

      final column = tester.widget<Column>(columnFinder);
      expect(column.mainAxisAlignment, MainAxisAlignment.start);
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);

      final textFinders = find.descendant(
        of: columnFinder,
        matching: find.byType(Text),
      );
      expect(textFinders, findsNWidgets(2));

      final nameText = tester.widget<Text>(textFinders.first);
      expect(nameText.style?.fontWeight, FontWeight.bold);
      expect(nameText.style?.fontSize, 18);

      final messageText = tester.widget<Text>(textFinders.last);
      expect(messageText.style?.fontSize, 14);
    });

    testWidgets('MessageWidget renders correctly for "to" direction', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              name: 'Maria',
              message: 'Tudo bem?',
              direction: MessageDirection.to,
            ),
          ),
        ),
      );

      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('Tudo bem?'), findsOneWidget);

      final messageFinder = find.byType(MessageWidget);
      expect(messageFinder, findsOneWidget);

      final messageWidget = tester.widget<MessageWidget>(messageFinder);
      expect(messageWidget.direction, MessageDirection.to);

      final containerFinder = find.descendant(
        of: messageFinder,
        matching: find.byWidgetPredicate((widget) => widget is Container),
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color.fromARGB(255, 74, 200, 220));
      expect(decoration.borderRadius, const BorderRadius.only(
        bottomRight: Radius.circular(20),
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ));
      expect(container.margin, const EdgeInsets.fromLTRB(10, 10, 100, 10));
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 20, vertical: 15));
    });
  });
}