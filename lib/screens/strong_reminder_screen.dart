import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/reminder.dart';
import '../models/strong_reminder_payload.dart';

class StrongReminderScreen extends StatefulWidget {
  const StrongReminderScreen({super.key, required this.payload});

  final StrongReminderPayload payload;

  @override
  State<StrongReminderScreen> createState() => _StrongReminderScreenState();
}

class _StrongReminderScreenState extends State<StrongReminderScreen> {
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _pulse();
    _pulseTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pulse());
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _pulse() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  }

  Future<void> _dismiss() async {
    _pulseTimer?.cancel();
    unawaited(
      FlutterLocalNotificationsPlugin().cancel(
        Reminder.normalizeId(widget.payload.id),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F3EA8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filledTonal(
                    tooltip: '关闭',
                    onPressed: _dismiss,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.alarm_on_outlined,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  widget.payload.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.payload.body,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFEAF1FF),
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '已到达提醒范围，请处理后关闭。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFCFE0FF),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _dismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colorScheme.primary,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('知道了'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
