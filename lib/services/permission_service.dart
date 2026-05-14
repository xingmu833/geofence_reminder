import 'package:permission_handler/permission_handler.dart';

class AppPermissionSnapshot {
  const AppPermissionSnapshot({
    required this.location,
    required this.backgroundLocation,
    required this.notification,
    required this.batteryOptimization,
  });

  final PermissionStatus location;
  final PermissionStatus backgroundLocation;
  final PermissionStatus notification;
  final PermissionStatus batteryOptimization;

  bool get locationReady => location.isGranted;

  bool get backgroundReady => backgroundLocation.isGranted;

  bool get notificationReady => notification.isGranted;

  bool get batteryReady => batteryOptimization.isGranted;
}

class AppPermissionService {
  const AppPermissionService();

  Future<AppPermissionSnapshot> loadStatuses() async {
    return AppPermissionSnapshot(
      location: await Permission.locationWhenInUse.status,
      backgroundLocation: await Permission.locationAlways.status,
      notification: await Permission.notification.status,
      batteryOptimization: await Permission.ignoreBatteryOptimizations.status,
    );
  }

  Future<AppPermissionSnapshot> requestLocationPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
    return loadStatuses();
  }

  Future<AppPermissionSnapshot> requestNotificationPermission() async {
    await Permission.notification.request();
    return loadStatuses();
  }

  Future<AppPermissionSnapshot> requestBatteryOptimizationPermission() async {
    await Permission.ignoreBatteryOptimizations.request();
    return loadStatuses();
  }

  Future<bool> openSystemSettings() {
    return openAppSettings();
  }
}
