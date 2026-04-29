import 'package:flutter/material.dart';

class MapPicker extends StatelessWidget {
  const MapPicker({
    super.key,
    required this.radiusMeters,
    required this.hasPin,
    required this.onPinChanged,
  });

  final int radiusMeters;
  final bool hasPin;
  final ValueChanged<bool> onPinChanged;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapPainter()),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => onPinChanged(true),
                onLongPress: () => onPinChanged(true),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: hasPin ? 1 : 0.82,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: hasPin ? 1 : 0,
                  child: _Pin(radiusMeters: radiusMeters),
                ),
              ),
            ),
            const Positioned(
              left: 14,
              top: 14,
              child: _MapBadge(icon: Icons.near_me_outlined, text: '点击地图选择位置'),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: FloatingActionButton.small(
                heroTag: 'mapPickerLocate',
                tooltip: '回到当前位置',
                onPressed: () => onPinChanged(true),
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.radiusMeters});

  final int radiusMeters;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final circleSize = switch (radiusMeters) {
      100 => 92.0,
      200 => 126.0,
      500 => 168.0,
      _ => 210.0,
    };

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.13),
              border: Border.all(
                color: primary.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: primary, size: 20),
                const SizedBox(width: 4),
                Text(
                  radiusMeters >= 1000 ? '1km' : '${radiusMeters}m',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
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

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE6EEE4);
    canvas.drawRect(Offset.zero & size, background);

    final blockPaint = Paint()..color = const Color(0xFFD7E3D3);
    final parkPaint = Paint()..color = const Color(0xFFC7DDC4);
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final roadThinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.06,
          size.height * 0.10,
          size.width * 0.26,
          size.height * 0.22,
        ),
        const Radius.circular(12),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.68,
          size.height * 0.16,
          size.width * 0.22,
          size.height * 0.30,
        ),
        const Radius.circular(12),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.68,
          size.width * 0.34,
          size.height * 0.20,
        ),
        const Radius.circular(12),
      ),
      blockPaint,
    );

    canvas.drawLine(
      Offset(-20, size.height * 0.40),
      Offset(size.width + 20, size.height * 0.24),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, -20),
      Offset(size.width * 0.78, size.height + 20),
      roadPaint,
    );
    canvas.drawLine(
      Offset(-20, size.height * 0.76),
      Offset(size.width + 20, size.height * 0.58),
      roadThinPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, -20),
      Offset(size.width * 0.18, size.height + 20),
      roadThinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
