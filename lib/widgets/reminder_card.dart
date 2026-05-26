import 'package:flutter/material.dart';

import '../models/reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggle,
  });

  final Reminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = reminder.isEnabled
        ? const Color(0xFF60708F)
        : const Color(0xFF9AA8BD);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x182563EB),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: reminder.isEnabled
                              ? const [Colors.white, Color(0xFFF7FBFF)]
                              : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -18,
                    top: -18,
                    child: Transform.rotate(
                      angle: -0.28,
                      child: Container(
                        width: 108,
                        height: 54,
                        decoration: BoxDecoration(
                          color: (reminder.isEnabled ? primary : muted)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: reminder.isEnabled
                                  ? const [
                                      Color(0xFFEAF1FF),
                                      Color(0xFFF0FBF8),
                                    ]
                                  : const [
                                      Color(0xFFF1F5F9),
                                      Color(0xFFE8EEF6),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white),
                            boxShadow: [
                              BoxShadow(
                                color: (reminder.isEnabled ? primary : muted)
                                    .withValues(alpha: 0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            reminder.alertMode == AlertMode.alarm
                                ? Icons.alarm_outlined
                                : Icons.location_on_outlined,
                            color: reminder.isEnabled ? primary : muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reminder.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: reminder.isEnabled
                                                ? const Color(0xFF10203F)
                                                : muted,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(isEnabled: reminder.isEnabled),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reminder.locationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: reminder.isEnabled
                                      ? const Color(0xFF42516D)
                                      : const Color(0xFF9AA8BD),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    icon: Icons.radio_button_unchecked,
                                    text: reminder.radiusLabel,
                                  ),
                                  _MetaChip(
                                    icon: Icons.schedule,
                                    text: reminder.scheduleLabel,
                                  ),
                                  _MetaChip(
                                    icon: reminder.alertMode == AlertMode.alarm
                                        ? Icons.alarm_outlined
                                        : Icons.notifications_none_outlined,
                                    text: reminder.alertModeLabel,
                                  ),
                                  _MetaChip(
                                    icon: Icons.repeat,
                                    text: reminder.triggerLimitLabel,
                                  ),
                                ],
                              ),
                              if (reminder.displayLastTriggeredLabel != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '上次触发：${reminder.displayLastTriggeredLabel}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: const Color(0xFF60708F)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Switch(value: reminder.isEnabled, onChanged: onToggle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? const Color(0xFF2563EB) : const Color(0xFF8A97AE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Text(
        isEnabled ? '生效' : '暂停',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE3EBFA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF60708F)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF52627F),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
