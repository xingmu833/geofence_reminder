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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: reminder.isEnabled
                      ? const Color(0xFFEAF1FF)
                      : const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(14),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF60708F),
                        ),
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
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(99),
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
