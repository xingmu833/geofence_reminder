import 'package:flutter/material.dart';

class AppFeedbackDialog {
  const AppFeedbackDialog._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    String actionLabel = '知道了',
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(icon),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction?.call();
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.help_outline,
    String cancelLabel = '取消',
    String confirmLabel = '确定',
  }) async {
    if (!context.mounted) {
      return false;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: Icon(icon),
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
