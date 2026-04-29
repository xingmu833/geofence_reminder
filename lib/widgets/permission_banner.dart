import 'package:flutter/material.dart';

class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0D9A9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFFC27A2C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '后台提醒需要完整权限',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A3517),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '定位、通知和电池优化白名单都开启后，到达地点时才能稳定提醒。',
                  style: TextStyle(color: Color(0xFF73552A), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onOpenSettings, child: const Text('去设置')),
        ],
      ),
    );
  }
}
