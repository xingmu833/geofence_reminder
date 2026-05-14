import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';

import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeBaiduMap();
  bg.BackgroundGeolocation.registerHeadlessTask(
    backgroundGeolocationHeadlessTask,
  );
  runApp(const GeofenceReminderApp());
}

Future<void> _initializeBaiduMap() async {
  BMFMapSDK.setAgreePrivacy(true);

  if (Platform.isAndroid) {
    const androidKey = String.fromEnvironment('BAIDU_ANDROID_KEY');
    await BMFAndroidVersion.initAndroidVersion();
    BMFMapSDK.setApiKeyAndCoordType(androidKey, BMF_COORD_TYPE.BD09LL);
  } else if (Platform.isIOS) {
    const iosKey = String.fromEnvironment('BAIDU_IOS_KEY');
    BMFMapSDK.setApiKeyAndCoordType(iosKey, BMF_COORD_TYPE.BD09LL);
  }
}

@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent event) async {
  if (event.name != bg.Event.GEOFENCE) {
    return;
  }

  final geofenceEvent = event.event as bg.GeofenceEvent;
  if (geofenceEvent.action != 'ENTER') {
    return;
  }

  final reminderId = int.tryParse(
    geofenceEvent.identifier.replaceFirst('reminder-', ''),
  );
  if (reminderId == null) {
    return;
  }

  await NotificationService.showGeofenceReminder(
    id: reminderId,
    title: '到达提醒地点',
    body: geofenceEvent.extras?['title'] as String? ?? '你有一条位置提醒',
  );
}

class GeofenceReminderApp extends StatelessWidget {
  const GeofenceReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF28785E);

    return MaterialApp(
      title: '临场记',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF6F8F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8F4),
          foregroundColor: Color(0xFF16231D),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE2E8DE)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE6DA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDE6DA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: seed, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: seed,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
