import 'package:flutter/material.dart';

class RadiusSelector extends StatelessWidget {
  const RadiusSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  static const List<int> _options = [100, 200, 500, 1000];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '围栏半径',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              value >= 1000 ? '1km' : '${value}m',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              constraints: BoxConstraints.expand(
                width: (constraints.maxWidth - 6) / 4,
                height: 44,
              ),
              isSelected: _options.map((option) => option == value).toList(),
              onPressed: (index) => onChanged(_options[index]),
              children: const [
                Text('100m'),
                Text('200m'),
                Text('500m'),
                Text('1km'),
              ],
            );
          },
        ),
      ],
    );
  }
}
