import 'dart:math' as math;

import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';

class CoordinateTransform {
  const CoordinateTransform._();

  static const double _pi = math.pi;
  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;
  static const double _xPi = _pi * 3000.0 / 180.0;

  static BMFCoordinate wgs84ToBd09(double latitude, double longitude) {
    final gcj = _wgs84ToGcj02(latitude, longitude);
    return _gcj02ToBd09(gcj.latitude, gcj.longitude);
  }

  static BMFCoordinate bd09ToWgs84(double latitude, double longitude) {
    final gcj = _bd09ToGcj02(latitude, longitude);
    return _gcj02ToWgs84(gcj.latitude, gcj.longitude);
  }

  static BMFCoordinate _wgs84ToGcj02(double latitude, double longitude) {
    if (_outOfChina(latitude, longitude)) {
      return BMFCoordinate(latitude, longitude);
    }

    var dLat = _transformLat(longitude - 105.0, latitude - 35.0);
    var dLon = _transformLon(longitude - 105.0, latitude - 35.0);
    final radLat = latitude / 180.0 * _pi;
    var magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * _pi);
    dLon = (dLon * 180.0) / (_a / sqrtMagic * math.cos(radLat) * _pi);

    return BMFCoordinate(latitude + dLat, longitude + dLon);
  }

  static BMFCoordinate _gcj02ToWgs84(double latitude, double longitude) {
    if (_outOfChina(latitude, longitude)) {
      return BMFCoordinate(latitude, longitude);
    }

    final gcj = _wgs84ToGcj02(latitude, longitude);
    return BMFCoordinate(
      latitude * 2 - gcj.latitude,
      longitude * 2 - gcj.longitude,
    );
  }

  static BMFCoordinate _gcj02ToBd09(double latitude, double longitude) {
    final z =
        math.sqrt(longitude * longitude + latitude * latitude) +
        0.00002 * math.sin(latitude * _xPi);
    final theta =
        math.atan2(latitude, longitude) + 0.000003 * math.cos(longitude * _xPi);
    return BMFCoordinate(
      z * math.sin(theta) + 0.006,
      z * math.cos(theta) + 0.0065,
    );
  }

  static BMFCoordinate _bd09ToGcj02(double latitude, double longitude) {
    final x = longitude - 0.0065;
    final y = latitude - 0.006;
    final z = math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * _xPi);
    final theta = math.atan2(y, x) - 0.000003 * math.cos(x * _xPi);
    return BMFCoordinate(z * math.sin(theta), z * math.cos(theta));
  }

  static bool _outOfChina(double latitude, double longitude) {
    return longitude < 72.004 ||
        longitude > 137.8347 ||
        latitude < 0.8293 ||
        latitude > 55.8271;
  }

  static double _transformLat(double x, double y) {
    var ret =
        -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret +=
        (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
        2.0 /
        3.0;
    ret +=
        (20.0 * math.sin(y * _pi) + 40.0 * math.sin(y / 3.0 * _pi)) * 2.0 / 3.0;
    ret +=
        (160.0 * math.sin(y / 12.0 * _pi) + 320 * math.sin(y * _pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    var ret =
        300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret +=
        (20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) *
        2.0 /
        3.0;
    ret +=
        (20.0 * math.sin(x * _pi) + 40.0 * math.sin(x / 3.0 * _pi)) * 2.0 / 3.0;
    ret +=
        (150.0 * math.sin(x / 12.0 * _pi) + 300.0 * math.sin(x / 30.0 * _pi)) *
        2.0 /
        3.0;
    return ret;
  }
}
