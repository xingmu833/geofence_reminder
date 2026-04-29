import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../widgets/permission_banner.dart';
import '../widgets/reminder_card.dart';
import 'reminder_editor_screen.dart';
import 'settings_screen.dart';

enum _ReminderFilter { all, active, paused }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<Reminder> _reminders;
  String _query = '';
  _ReminderFilter _filter = _ReminderFilter.all;

  @override
  void initState() {
    super.initState();
    _reminders = Reminder.demoList();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Reminder> get _visibleReminders {
    Iterable<Reminder> result = _reminders;

    result = switch (_filter) {
      _ReminderFilter.all => result,
      _ReminderFilter.active => result.where((item) => item.isEnabled),
      _ReminderFilter.paused => result.where((item) => !item.isEnabled),
    };

    if (_query.isNotEmpty) {
      final lower = _query.toLowerCase();
      result = result.where(
        (item) =>
            item.title.toLowerCase().contains(lower) ||
            item.locationName.toLowerCase().contains(lower),
      );
    }

    return result.toList();
  }

  Future<void> _openEditor([Reminder? reminder]) async {
    final result = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute(
        builder: (_) => ReminderEditorScreen(reminder: reminder),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      final index = _reminders.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _reminders = [result, ..._reminders];
      } else {
        _reminders[index] = result;
      }
    });
  }

  void _deleteReminder(Reminder reminder) {
    setState(() {
      _reminders.removeWhere((item) => item.id == reminder.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${reminder.locationName}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () =>
              setState(() => _reminders = [reminder, ..._reminders]),
        ),
      ),
    );
  }

  void _toggleReminder(Reminder reminder, bool enabled) {
    setState(() {
      final index = _reminders.indexWhere((item) => item.id == reminder.id);
      _reminders[index] = reminder.copyWith(isEnabled: enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _reminders.where((item) => item.isEnabled).length;
    final pausedCount = _reminders.length - activeCount;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeHeader(
                      onAdd: () => _openEditor(),
                      onSettings: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: '搜索地点或提醒内容',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PermissionBanner(
                      onOpenSettings: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _StatusStrip(
                      activeCount: activeCount,
                      pausedCount: pausedCount,
                      totalCount: _reminders.length,
                    ),
                    const SizedBox(height: 14),
                    _FilterBar(
                      value: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ],
                ),
              ),
            ),
            if (_visibleReminders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  hasQuery: _query.isNotEmpty || _filter != _ReminderFilter.all,
                  onAdd: () => _openEditor(),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _filter = _ReminderFilter.all);
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                sliver: SliverList.separated(
                  itemCount: _visibleReminders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reminder = _visibleReminders[index];
                    return Dismissible(
                      key: ValueKey(reminder.id),
                      direction: DismissDirection.endToStart,
                      background: const SizedBox.shrink(),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB9493C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) => _deleteReminder(reminder),
                      child: ReminderCard(
                        reminder: reminder,
                        onTap: () => _openEditor(reminder),
                        onToggle: (enabled) =>
                            _toggleReminder(reminder, enabled),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('新增提醒'),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onAdd, required this.onSettings});

  final VoidCallback onAdd;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '临场记',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16231D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '到地方，自动想起来',
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF66756C),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '设置',
          onPressed: onSettings,
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: '新增提醒',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.activeCount,
    required this.pausedCount,
    required this.totalCount,
  });

  final int activeCount;
  final int pausedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            label: '生效中',
            value: '$activeCount',
            icon: Icons.radar_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            label: '暂停',
            value: '$pausedCount',
            icon: Icons.pause_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            label: '全部',
            value: '$totalCount',
            icon: Icons.list_alt_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF66756C)),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _ReminderFilter value;
  final ValueChanged<_ReminderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ReminderFilter>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: _ReminderFilter.all,
          icon: Icon(Icons.inbox_outlined),
          label: Text('全部'),
        ),
        ButtonSegment(
          value: _ReminderFilter.active,
          icon: Icon(Icons.notifications_active_outlined),
          label: Text('生效'),
        ),
        ButtonSegment(
          value: _ReminderFilter.paused,
          icon: Icon(Icons.pause_circle_outline),
          label: Text('暂停'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasQuery,
    required this.onAdd,
    required this.onClear,
  });

  final bool hasQuery;
  final VoidCallback onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasQuery ? Icons.manage_search : Icons.add_location_alt_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasQuery ? '没有匹配的提醒' : '暂无提醒',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery ? '换个关键词或查看全部状态。' : '点击新增，在地图上圈出到达后需要提醒的位置。',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF66756C)),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: hasQuery ? onClear : onAdd,
            icon: Icon(hasQuery ? Icons.refresh : Icons.add),
            label: Text(hasQuery ? '查看全部' : '新增提醒'),
          ),
        ],
      ),
    );
  }
}
