import 'dart:typed_data';

import 'package:flutter/material.dart';

class StrongReminderVisualFrame extends StatelessWidget {
  const StrongReminderVisualFrame({
    super.key,
    required this.width,
    required this.height,
    this.imageBytes,
    this.assetPath = 'assets/images/strong_reminder_character.jpg',
    this.angle = -0.06,
  });

  final double width;
  final double height;
  final Uint8List? imageBytes;
  final String assetPath;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 34,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: imageBytes != null
              ? Image.memory(
                  imageBytes!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                )
              : Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
        ),
      ),
    );
  }
}
