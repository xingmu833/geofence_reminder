import 'dart:convert';
import 'dart:io';

import '../utils/coordinate_transform.dart';

class GeocodingResult {
  const GeocodingResult({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class BaiduGeocodingService {
  const BaiduGeocodingService();

  static const _apiKey = String.fromEnvironment('BAIDU_ANDROID_KEY');

  Future<GeocodingResult?> searchAddress(String address) async {
    final query = address.trim();
    if (query.isEmpty || _apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.https('api.map.baidu.com', '/geocoding/v3/', {
      'address': query,
      'output': 'json',
      'ak': _apiKey,
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 0) {
        return null;
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        return null;
      }

      final location = result['location'];
      if (location is! Map<String, dynamic>) {
        return null;
      }

      final latitude = (location['lat'] as num?)?.toDouble();
      final longitude = (location['lng'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return null;
      }

      final wgs84 = CoordinateTransform.bd09ToWgs84(latitude, longitude);
      return GeocodingResult(
        latitude: wgs84.latitude,
        longitude: wgs84.longitude,
      );
    } finally {
      client.close();
    }
  }
}
