import 'package:flutter/material.dart';

import '../models/strong_reminder_payload.dart';
import '../screens/strong_reminder_screen.dart';

class AppNavigationService {
  AppNavigationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static StrongReminderPayload? _pendingStrongReminder;

  static void showStrongReminder(StrongReminderPayload payload) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingStrongReminder = payload;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingStrongReminder;
        if (pending != null) {
          _pendingStrongReminder = null;
          showStrongReminder(pending);
        }
      });
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => StrongReminderScreen(payload: payload),
      ),
    );
  }
}
