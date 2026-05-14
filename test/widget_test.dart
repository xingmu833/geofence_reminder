import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_reminder/main.dart';
import 'package:geofence_reminder/widgets/map_picker.dart';
import 'package:geofence_reminder/widgets/radius_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders reminder home page and opens editor', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const GeofenceReminderApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.add_location_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MapPicker), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(RadiusSelector),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byType(RadiusSelector), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.save_outlined),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
  });
}
