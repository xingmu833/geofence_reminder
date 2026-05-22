import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceSupportInfo {
  const DeviceSupportInfo({
    required this.manufacturer,
    required this.brand,
    required this.vendorName,
    required this.steps,
  });

  final String manufacturer;
  final String brand;
  final String vendorName;
  final List<String> steps;

  bool get hasVendorGuide => steps.isNotEmpty;

  String get subtitle {
    if (steps.isEmpty) {
      return '不同系统可能需要手动允许后台运行、锁屏通知和自启动';
    }
    return steps.join('，');
  }

  factory DeviceSupportInfo.generic() {
    return const DeviceSupportInfo(
      manufacturer: '',
      brand: '',
      vendorName: '当前设备',
      steps: [
        '允许后台定位',
        '关闭省电限制',
        '允许锁屏通知',
      ],
    );
  }

  factory DeviceSupportInfo.fromAndroid({
    required String manufacturer,
    required String brand,
  }) {
    final lower = '$manufacturer $brand'.toLowerCase();
    if (lower.contains('xiaomi') ||
        lower.contains('redmi') ||
        lower.contains('poco')) {
      return DeviceSupportInfo(
        manufacturer: manufacturer,
        brand: brand,
        vendorName: '小米 / Redmi',
        steps: const [
          '允许自启动',
          '电量设置改为无限制',
          '允许锁屏通知和悬浮通知',
        ],
      );
    }
    if (lower.contains('vivo') || lower.contains('iqoo')) {
      return DeviceSupportInfo(
        manufacturer: manufacturer,
        brand: brand,
        vendorName: 'vivo / iQOO',
        steps: const [
          '允许后台高耗电',
          '开启自启动',
          '允许锁屏通知',
        ],
      );
    }
    if (lower.contains('oppo') ||
        lower.contains('realme') ||
        lower.contains('oneplus')) {
      return DeviceSupportInfo(
        manufacturer: manufacturer,
        brand: brand,
        vendorName: 'OPPO / realme / 一加',
        steps: const [
          '允许自启动',
          '后台耗电管理设为允许',
          '允许锁屏通知',
        ],
      );
    }
    if (lower.contains('huawei') || lower.contains('honor')) {
      return DeviceSupportInfo(
        manufacturer: manufacturer,
        brand: brand,
        vendorName: '华为 / 荣耀',
        steps: const [
          '应用启动管理改为手动管理',
          '允许后台活动',
          '允许锁屏通知',
        ],
      );
    }
    return DeviceSupportInfo(
      manufacturer: manufacturer,
      brand: brand,
      vendorName: manufacturer.isEmpty ? '当前设备' : manufacturer,
      steps: const [
        '允许后台运行',
        '关闭省电限制',
        '允许锁屏通知',
      ],
    );
  }
}

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

  static const MethodChannel _deviceSettingsChannel = MethodChannel(
    'geofence_reminder/device_settings',
  );

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
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.activityRecognition.request();
    }
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

  Future<DeviceSupportInfo> loadDeviceSupportInfo() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return DeviceSupportInfo.generic();
    }

    try {
      final info = await _deviceSettingsChannel.invokeMapMethod<String, String>(
        'getDeviceInfo',
      );
      return DeviceSupportInfo.fromAndroid(
        manufacturer: info?['manufacturer'] ?? '',
        brand: info?['brand'] ?? '',
      );
    } catch (_) {
      return DeviceSupportInfo.generic();
    }
  }

  Future<bool> openVendorPowerSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return openSystemSettings();
    }

    try {
      final opened = await _deviceSettingsChannel.invokeMethod<bool>(
        'openVendorPowerSettings',
      );
      return opened ?? false;
    } catch (_) {
      return openSystemSettings();
    }
  }
}
