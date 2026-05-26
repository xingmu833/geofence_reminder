import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/reminder.dart';
import '../models/strong_reminder_payload.dart';
import '../services/alarm_audio_service.dart';
import '../services/app_settings_store.dart';
import '../services/notification_service.dart';
import '../services/strong_reminder_visual_service.dart';
import '../widgets/strong_reminder_visual_frame.dart';

class StrongReminderScreen extends StatefulWidget {
  const StrongReminderScreen({super.key, required this.payload});

  final StrongReminderPayload payload;

  @override
  State<StrongReminderScreen> createState() => _StrongReminderScreenState();
}

class _StrongReminderScreenState extends State<StrongReminderScreen> {
  final AlarmAudioService _alarmAudioService = const AlarmAudioService();
  final StrongReminderVisualService _visualService =
      const StrongReminderVisualService();
  Timer? _pulseTimer;
  StrongReminderVisualSelection? _visualSelection;
  int _snoozeMinutes = 10;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _startAlarmSound();
    _loadVisual();
    _pulse();
    _pulseTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pulse());
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _pulse() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> _startAlarmSound() async {
    final settings = await const AppSettingsStore().load();
    if (!mounted) {
      return;
    }
    await _alarmAudioService.start(settings.alarmSound);
  }

  Future<void> _loadVisual() async {
    final selection = await _visualService.loadSelection();
    if (!mounted) {
      return;
    }
    setState(() {
      _visualSelection = selection;
    });
  }

  Future<void> _dismiss() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    await _stopCurrentReminder();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    await NotificationService.scheduleSnoozeStrongReminder(
      payload: widget.payload,
      delay: Duration(minutes: _snoozeMinutes),
    );
    await _stopCurrentReminder();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _stopCurrentReminder() async {
    _pulseTimer?.cancel();
    await _alarmAudioService.stop();
    unawaited(
      FlutterLocalNotificationsPlugin().cancel(
        Reminder.normalizeId(widget.payload.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            const _Backdrop(),
            const Positioned(
              top: 18,
              left: -22,
              child: _GlowBlob(
                size: 150,
                color: Color(0xFFF6D7C8),
              ),
            ),
            const Positioned(
              top: 108,
              right: -55,
              child: _GlowBlob(
                size: 160,
                color: Color(0xFFC9E5FF),
              ),
            ),
            const Positioned(
              bottom: 72,
              left: -18,
              child: _GlowBlob(
                size: 180,
                color: Color(0xFFDDEDD7),
              ),
            ),
            Positioned(
              left: -size.width * 0.01,
              top: size.height * 0.1,
              child: StrongReminderVisualFrame(
                imageBytes: _visualSelection?.bytes,
                width: size.width * 0.58,
                height: size.height * 0.38,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(textTheme: textTheme),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: _GlassCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ReminderBadge(
                                  color: const Color(0xFF0F3EA8),
                                  label: '强提醒',
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  widget.payload.title,
                                  style: textTheme.headlineMedium?.copyWith(
                                    color: const Color(0xFF10203F),
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.payload.body,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF344863),
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '已进入强提醒状态，处理完后点击“知道了”停止铃声。',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF60708F),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _SnoozePicker(
                                  value: _snoozeMinutes,
                                  onChanged: (value) =>
                                      setState(() => _snoozeMinutes = value),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _snooze,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F3EA8),
                                    side: const BorderSide(
                                      color: Color(0xFFD2DEF3),
                                    ),
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.snooze),
                                  label: Text('稍后$_snoozeMinutes分钟提醒我'),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _dismiss,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F3EA8),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('知道了'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
          ),
          child: const Icon(
            Icons.alarm_on_rounded,
            color: Color(0xFF0F3EA8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '强提醒',
                style: textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF10203F),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '处理完后再关闭铃声',
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF60708F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 30,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF9F7F3), Color(0xFFF4EFE6), Color(0xFFEAF2F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.46),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 34,
            spreadRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SnoozePicker extends StatelessWidget {
  const _SnoozePicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _minutes = [5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F3)),
      ),
      child: Row(
        children: [
          for (final minute in _minutes)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(minute),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == minute
                        ? const Color(0xFF0F3EA8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$minute分钟',
                    style: TextStyle(
                      color: value == minute
                          ? Colors.white
                          : const Color(0xFF60708F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
