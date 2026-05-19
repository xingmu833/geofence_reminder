import 'dart:async';

import 'package:flutter_baidu_mapapi_search/flutter_baidu_mapapi_search.dart';

import '../utils/coordinate_transform.dart';

class BaiduPlaceResult {
  const BaiduPlaceResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.district,
    this.distanceMeters,
  });

  final String name;
  final String? address;
  final String? city;
  final String? district;
  final double latitude;
  final double longitude;
  final int? distanceMeters;

  String get subtitle {
    final parts = [
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (district != null && district!.trim().isNotEmpty) district!.trim(),
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
    ];
    return parts.join(' ');
  }
}

class BaiduGeocodingService {
  const BaiduGeocodingService();

  Future<List<BaiduPlaceResult>> searchNearbyPlaces({
    required String keyword,
    required double centerLatitude,
    required double centerLongitude,
    int radiusMeters = 5000,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return const [];
    }

    final completer = Completer<List<BaiduPlaceResult>>();
    final search = BMFPoiNearbySearch();
    search.onGetPoiNearbySearchResult(
      callback: (result, errorCode) {
        if (completer.isCompleted) {
          return;
        }

        if (errorCode != BMFSearchErrorCode.NO_ERROR) {
          completer.complete(const []);
          return;
        }

        final places = (result.poiInfoList ?? [])
            .map(_placeFromPoi)
            .whereType<BaiduPlaceResult>()
            .toList(growable: false);
        completer.complete(places);
      },
    );

    final center = CoordinateTransform.wgs84ToBd09(
      centerLatitude,
      centerLongitude,
    );
    final started = await search.poiNearbySearch(
      BMFPoiNearbySearchOption(
        keywords: [query],
        location: center,
        radius: radiusMeters,
        isRadiusLimit: false,
        pageIndex: 0,
        pageSize: 15,
      ),
    );

    if (!started) {
      return const [];
    }

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => const [],
    );
  }

  BaiduPlaceResult? _placeFromPoi(BMFPoiInfo poi) {
    final name = poi.name?.trim();
    final point = poi.pt;
    if (name == null || name.isEmpty || point == null) {
      return null;
    }

    final wgs84 = CoordinateTransform.bd09ToWgs84(
      point.latitude,
      point.longitude,
    );
    return BaiduPlaceResult(
      name: name,
      address: poi.address,
      city: poi.city,
      district: poi.area,
      latitude: wgs84.latitude,
      longitude: wgs84.longitude,
      distanceMeters: poi.detailInfo?.distance ?? poi.distance,
    );
  }
}
