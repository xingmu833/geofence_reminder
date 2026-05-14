import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';

import '../utils/coordinate_transform.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    required this.radiusMeters,
    required this.hasPin,
    required this.latitude,
    required this.longitude,
    required this.onPinChanged,
    required this.onLocationChanged,
  });

  final int radiusMeters;
  final bool hasPin;
  final double latitude;
  final double longitude;
  final ValueChanged<bool> onPinChanged;
  final void Function(double latitude, double longitude) onLocationChanged;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  static const _androidKey = String.fromEnvironment('BAIDU_ANDROID_KEY');

  BMFMapController? _mapController;

  BMFCoordinate get _selectedBd09Point =>
      CoordinateTransform.wgs84ToBd09(widget.latitude, widget.longitude);

  @override
  void didUpdateWidget(covariant MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.radiusMeters != widget.radiusMeters ||
        oldWidget.hasPin != widget.hasPin) {
      _refreshOverlays();
      _mapController?.setCenterCoordinate(_selectedBd09Point, true);
    }
  }

  void _selectBd09Point(BMFCoordinate point, {bool moveMap = false}) {
    final wgs84 = CoordinateTransform.bd09ToWgs84(
      point.latitude,
      point.longitude,
    );
    widget.onPinChanged(true);
    widget.onLocationChanged(wgs84.latitude, wgs84.longitude);

    if (moveMap) {
      _mapController?.setCenterCoordinate(point, true);
    }
  }

  Future<void> _locateCurrentPosition() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        timeout: 12,
        persist: false,
      );
      final coords = location.coords;
      final bd09 = CoordinateTransform.wgs84ToBd09(
        coords.latitude,
        coords.longitude,
      );
      _selectBd09Point(bd09, moveMap: true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('已定位到当前位置'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('定位失败，请检查定位权限或稍后重试')),
      );
    }
  }

  Future<void> _onMapCreated(BMFMapController controller) async {
    _mapController = controller;
    controller.setMapOnClickedMapBlankCallback(
      callback: (coordinate) => _selectBd09Point(coordinate),
    );
    controller.setMapOnLongClickCallback(
      callback: (coordinate) => _selectBd09Point(coordinate),
    );
    await _refreshOverlays();
  }

  Future<void> _refreshOverlays() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.cleanAllMarkers();
    await controller.clearOverlays();
    if (!widget.hasPin) {
      return;
    }

    await controller.addCircle(
      BMFCircle(
        center: _selectedBd09Point,
        radius: widget.radiusMeters.toDouble(),
        width: 2,
        strokeColor: Colors.green,
        fillColor: const Color(0x3328785E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_androidKey.isEmpty) {
      return const _MissingBaiduKeyPanel();
    }

    final point = _selectedBd09Point;

    return AspectRatio(
      aspectRatio: 1.14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE6EEE4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8DE)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BMFTextureMapWidget(
              onBMFMapCreated: _onMapCreated,
              mapOptions: BMFMapOptions(
                center: point,
                zoomLevel: 16,
                mapType: BMFMapType.Standard,
                showZoomControl: false,
                showMapScaleBar: true,
              ),
            ),
            const Positioned(
              left: 14,
              top: 14,
              child: _MapBadge(
                icon: Icons.touch_app_outlined,
                text: '点击地图选择位置',
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: _CoordinateBadge(
                latitude: widget.latitude,
                longitude: widget.longitude,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: FloatingActionButton.small(
                heroTag: 'mapPickerLocate',
                tooltip: '回到当前位置',
                onPressed: _locateCurrentPosition,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingBaiduKeyPanel extends StatelessWidget {
  const _MissingBaiduKeyPanel();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.14,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8DE)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 40, color: Color(0xFF28785E)),
            SizedBox(height: 12),
            Text(
              '缺少百度地图 AK',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '请使用 --dart-define=BAIDU_ANDROID_KEY=你的AK 启动真机调试。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF66756C), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CoordinateBadge extends StatelessWidget {
  const _CoordinateBadge({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
