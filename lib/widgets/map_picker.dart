import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';

import '../services/native_geofence_bridge.dart';
import '../utils/coordinate_transform.dart';
import 'app_feedback_dialog.dart';

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
  BMFMapController? _mapController;
  bool _locationChangedByMap = false;
  bool _mapAlreadyMoved = false;
  bool _isLocatingCurrentPosition = false;
  Timer? _overlayRefreshTimer;
  final NativeGeofenceBridge _nativeGeofence = const NativeGeofenceBridge();

  BMFCoordinate get _selectedBd09Point =>
      CoordinateTransform.wgs84ToBd09(widget.latitude, widget.longitude);

  @override
  void dispose() {
    _overlayRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    final overlayChanged =
        locationChanged ||
        oldWidget.radiusMeters != widget.radiusMeters ||
        oldWidget.hasPin != widget.hasPin;

    if (overlayChanged) {
      _scheduleOverlayRefresh();
    }

    if (locationChanged && !_locationChangedByMap && !_mapAlreadyMoved) {
      _mapController?.setCenterCoordinate(_selectedBd09Point, true);
    }

    _locationChangedByMap = false;
    _mapAlreadyMoved = false;
  }

  void _selectBd09Point(
    BMFCoordinate point, {
    bool moveMap = false,
    bool fromMapGesture = false,
  }) {
    final wgs84 = CoordinateTransform.bd09ToWgs84(
      point.latitude,
      point.longitude,
    );

    _locationChangedByMap = fromMapGesture;
    _mapAlreadyMoved = moveMap;
    widget.onPinChanged(true);
    widget.onLocationChanged(wgs84.latitude, wgs84.longitude);

    if (moveMap) {
      _mapController?.setCenterCoordinate(point, true);
    }
  }

  Future<void> _locateCurrentPosition() async {
    if (_isLocatingCurrentPosition) {
      return;
    }

    setState(() => _isLocatingCurrentPosition = true);
    try {
      final coords = await _nativeGeofence.getCurrentPosition();
      final bd09 = CoordinateTransform.wgs84ToBd09(
        coords.latitude,
        coords.longitude,
      );
      _selectBd09Point(bd09, moveMap: true);
    } catch (_) {
      await AppFeedbackDialog.show(
        context,
        title: '定位失败',
        message: '请检查定位权限、系统定位开关，或稍后重试。',
        icon: Icons.location_disabled_outlined,
      );
    } finally {
      if (mounted) {
        setState(() => _isLocatingCurrentPosition = false);
      }
    }
  }

  Future<void> _onMapCreated(BMFMapController controller) async {
    _mapController = controller;
    controller.setMapOnClickedMapBlankCallback(
      callback: (coordinate) => _selectBd09Point(coordinate, moveMap: true),
    );
    controller.setMapOnLongClickCallback(
      callback: (coordinate) => _selectBd09Point(coordinate, moveMap: true),
    );
    controller.setMapRegionDidChangeCallback(
      callback: (status) {
        final center = status.targetGeoPt;
        if (center == null) {
          return;
        }
        _selectBd09Point(center, fromMapGesture: true);
      },
    );
    await _refreshOverlays();
  }

  Future<void> _refreshOverlays() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.clearOverlays();
    if (!widget.hasPin) {
      return;
    }

    await controller.addCircle(
      BMFCircle(
        center: _selectedBd09Point,
        radius: widget.radiusMeters.toDouble(),
        width: 2,
        strokeColor: const Color(0xFF2563EB),
        fillColor: const Color(0x332563EB),
      ),
    );
  }

  void _scheduleOverlayRefresh() {
    _overlayRefreshTimer?.cancel();
    _overlayRefreshTimer = Timer(const Duration(milliseconds: 80), () {
      _refreshOverlays();
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = _selectedBd09Point;

    return AspectRatio(
      aspectRatio: 1.14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD8E3F8)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BMFMapWidget(
                onBMFMapCreated: _onMapCreated,
                mapOptions: BMFMapOptions(
                  center: point,
                  zoomLevel: 16,
                  mapType: BMFMapType.Standard,
                  showZoomControl: false,
                  showMapScaleBar: true,
                  scrollEnabled: true,
                  zoomEnabled: true,
                ),
              ),
              const Positioned(
                left: 14,
                top: 14,
                child: _MapBadge(
                  icon: Icons.swipe_outlined,
                  text: '拖动地图调整选点',
                ),
              ),
              const Center(child: IgnorePointer(child: _CenterPin())),
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
                  onPressed: _isLocatingCurrentPosition
                      ? null
                      : _locateCurrentPosition,
                  child: _isLocatingCurrentPosition
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
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

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -18),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 42, color: Color(0xFF2563EB)),
          SizedBox(height: 2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x33000000),
              borderRadius: BorderRadius.all(Radius.elliptical(18, 6)),
            ),
            child: SizedBox(width: 24, height: 6),
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
        borderRadius: BorderRadius.circular(12),
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
