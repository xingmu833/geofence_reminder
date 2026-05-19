import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/geofence_service.dart';
import '../services/permission_service.dart';
import '../services/reminder_store.dart';
import '../widgets/app_feedback_dialog.dart';
import '../widgets/permission_banner.dart';
import '../widgets/reminder_card.dart';
import 'profile_screen.dart';
import 'reminder_editor_screen.dart';
import 'settings_screen.dart';

enum _ReminderFilter { all, active, paused }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppGeofenceService _geofenceService = const AppGeofenceService();
  final AppPermissionService _permissionService = const AppPermissionService();
  final ReminderStore _store = const ReminderStore();
  final TextEditingController _searchController = TextEditingController();
  List<Reminder> _reminders = const [];
  AppPermissionSnapshot? _permissionSnapshot;
  String _query = '';
  _ReminderFilter _filter = _ReminderFilter.all;
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _loadPermissionSnapshot();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final reminders = await _store.loadReminders();
    await _geofenceService.syncReminders(reminders);
    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _isLoading = false;
    });
  }

  Future<void> _loadPermissionSnapshot() async {
    final snapshot = await _permissionService.loadStatuses();
    if (!mounted) {
      return;
    }
    setState(() => _permissionSnapshot = snapshot);
  }

  Future<void> _saveReminders() {
    return Future.wait([
      _store.saveReminders(_reminders),
      _geofenceService.syncReminders(_reminders),
    ]).then((_) {});
  }

  bool get _permissionsReady {
    final snapshot = _permissionSnapshot;
    return snapshot != null &&
        snapshot.locationReady &&
        snapshot.backgroundReady &&
        snapshot.notificationReady &&
        snapshot.batteryReady;
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

    var isCreated = false;
    setState(() {
      final index = _reminders.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        isCreated = true;
        _reminders = [result, ..._reminders];
      } else {
        _reminders[index] = result;
      }
    });
    await _saveReminders();
    if (!mounted) {
      return;
    }
    await AppFeedbackDialog.show(
      context,
      title: isCreated ? '已创建提醒' : '已保存修改',
      message: '“${result.locationName}”的提醒规则已同步更新。',
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    setState(() {
      _reminders.removeWhere((item) => item.id == reminder.id);
    });
    await _saveReminders();

    if (!mounted) {
      return;
    }
    await AppFeedbackDialog.show(
      context,
      title: '已删除',
      message: '“${reminder.locationName}”已删除。',
      icon: Icons.check_circle_outline,
      actionLabel: '撤销',
      onAction: () {
        setState(() => _reminders = [reminder, ..._reminders]);
        _saveReminders();
      },
    );
  }

  Future<void> _toggleReminder(Reminder reminder, bool enabled) async {
    setState(() {
      final index = _reminders.indexWhere((item) => item.id == reminder.id);
      _reminders[index] = reminder.copyWith(isEnabled: enabled);
    });
    await _saveReminders();

    if (!mounted) {
      return;
    }
    await AppFeedbackDialog.show(
      context,
      title: enabled ? '已启用' : '已暂停',
      message: enabled
          ? '“${reminder.locationName}”已启用，到达后会触发提醒。'
          : '“${reminder.locationName}”已暂停，暂时不会触发提醒。',
      icon: enabled
          ? Icons.notifications_active_outlined
          : Icons.pause_circle_outline,
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _loadPermissionSnapshot();
    await _loadReminders();
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadPermissionSnapshot();
      _loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _reminders.where((item) => item.isEnabled).length;
    final pausedCount = _reminders.length - activeCount;

    return Scaffold(
      body: _selectedIndex == 0
          ? _isLoading
                ? const SafeArea(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SafeArea(
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
                                  onProfile: () => _selectTab(1),
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
                                if (!_permissionsReady) ...[
                                  const SizedBox(height: 14),
                                  PermissionBanner(
                                    onOpenSettings: _openSettings,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                _StatusStrip(
                                  activeCount: activeCount,
                                  pausedCount: pausedCount,
                                  totalCount: _reminders.length,
                                ),
                                const SizedBox(height: 14),
                                _FilterBar(
                                  value: _filter,
                                  onChanged: (value) =>
                                      setState(() => _filter = value),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_visibleReminders.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              hasQuery:
                                  _query.isNotEmpty ||
                                  _filter != _ReminderFilter.all,
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
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final reminder = _visibleReminders[index];
                                return Dismissible(
                                  key: ValueKey(reminder.id),
                                  direction: DismissDirection.endToStart,
                                  background: const SizedBox.shrink(),
                                  confirmDismiss: (_) {
                                    return AppFeedbackDialog.confirm(
                                      context,
                                      title: '删除提醒',
                                      message:
                                          '确定删除“${reminder.locationName}”吗？删除后会同步移除地理围栏监听。',
                                      icon: Icons.delete_outline,
                                      cancelLabel: '取消',
                                      confirmLabel: '删除',
                                    );
                                  },
                                  secondaryBackground: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE11D48),
                                      borderRadius: BorderRadius.circular(12),
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
                  )
          : const ProfileScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '事件',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '个人',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('新增提醒'),
            )
          : null,
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onAdd, required this.onProfile});

  final VoidCallback onAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '临场记',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '到地方，自动想起来',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFEAF1FF),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: '个人',
            onPressed: onProfile,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '新增提醒',
            onPressed: onAdd,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
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
        const SizedBox(width: 12),
        Expanded(
          child: _StatusTile(
            label: '暂停',
            value: '$pausedCount',
            icon: Icons.pause_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
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
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E3F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2563EB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
              color: const Color(0xFF10203F),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF60708F)),
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
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        selectedBackgroundColor: const Color(0xFFEAF1FF),
        selectedForegroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: const Color(0xFF52627F),
        side: const BorderSide(color: Color(0xFFD8E3F8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
            style: const TextStyle(color: Color(0xFF60708F)),
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
