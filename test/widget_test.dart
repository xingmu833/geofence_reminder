import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_reminder/main.dart';

void main() {
  testWidgets('renders reminder home page and opens editor', (tester) async {
    await tester.pumpWidget(const GeofenceReminderApp());

    expect(find.text('临场记'), findsOneWidget);
    expect(find.text('康宁大药房'), findsOneWidget);
    expect(find.text('新增提醒'), findsWidgets);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('新增提醒'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('围栏半径'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('围栏半径'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('创建提醒'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('创建提醒'), findsOneWidget);
  });
}
