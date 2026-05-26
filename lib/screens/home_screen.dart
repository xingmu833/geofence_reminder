import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/geofence_service.dart';
import '../services/permission_service.dart';
import '../services/reminder_store.dart';
import '../services/user_profile_store.dart';
import '../widgets/app_feedback_dialog.dart';
import '../widgets/permission_banner.dart';
import '../widgets/reminder_card.dart';
import 'profile_screen.dart';
import 'reminder_editor_screen.dart';
import 'settings_screen.dart';
import 'test_screen.dart';

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
  final UserProfileStore _profileStore = const UserProfileStore();
  final TextEditingController _searchController = TextEditingController();
  List<Reminder> _reminders = const [];
  AppPermissionSnapshot? _permissionSnapshot;
  String _query = '';
  _ReminderFilter _filter = _ReminderFilter.all;
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _showTestTab = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _loadPermissionSnapshot();
    _loadTestAccess();
    _searchController.addListener(() {
      final nextQuery = _searchController.text.trim();
      if (nextQuery == _query) {
        return;
      }
      setState(() => _query = nextQuery);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    List<Reminder> reminders;
    try {
      reminders = await _store.loadReminders();
    } catch (_) {
      reminders = const [];
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _reminders = reminders;
      _isLoading = false;
    });
    _syncRemindersSilently(reminders);
  }

  Future<void> _loadPermissionSnapshot() async {
    final snapshot = await _permissionService.loadStatuses();
    if (!mounted) {
      return;
    }
    setState(() => _permissionSnapshot = snapshot);
  }

  Future<void> _loadTestAccess() async {
    final profile = await _profileStore.load();
    final nextShowTestTab =
        profile.isLoggedIn &&
        profile.phone == '11111111111' &&
        profile.password == '123456c';
    if (!mounted) {
      return;
    }
    setState(() {
      _showTestTab = nextShowTestTab;
      if (!nextShowTestTab && _selectedIndex > 1) {
        _selectedIndex = 1;
      }
    });
  }

  Future<int> _saveReminders({
    bool checkCurrentLocation = false,
    int? immediateReminderId,
  }) async {
    await _store.saveReminders(_reminders);

    if (!checkCurrentLocation) {
      _syncRemindersSilently(_reminders);
      return 0;
    }

    try {
      final result = await _geofenceService.triggerMatchingCurrentLocation(
        _reminders,
        onlyReminderId: immediateReminderId,
      );
      if (result.triggeredCount == 0) {
        if (result.stateChangedCount > 0) {
          _reminders = result.reminders;
          await _store.saveReminders(_reminders);
          if (mounted) {
            setState(() {});
          }
        }
        _syncRemindersSilently(_reminders);
        return 0;
      }

      _reminders = result.reminders;
      await _store.saveReminders(_reminders);
      _syncRemindersSilently(_reminders);
      if (mounted) {
        setState(() {});
      }
      return result.triggeredCount;
    } catch (_) {
      _syncRemindersSilently(_reminders);
      return 0;
    }
  }

  void _syncRemindersSilently(List<Reminder> reminders) {
    unawaited(_geofenceService.syncReminders(reminders).catchError((_) {}));
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

    setState(() {
      final index = _reminders.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _reminders = [result, ..._reminders];
      } else {
        _reminders[index] = result;
      }
    });
    await _saveReminders(
      checkCurrentLocation: true,
      immediateReminderId: result.id,
    );
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    setState(() {
      _reminders.removeWhere((item) => item.id == reminder.id);
    });
    await _store.moveToTrash(reminder);
    await _saveReminders();
  }

  Future<void> _toggleReminder(Reminder reminder, bool enabled) async {
    setState(() {
      final index = _reminders.indexWhere((item) => item.id == reminder.id);
      _reminders[index] = reminder.copyWith(isEnabled: enabled);
    });
    await _saveReminders(
      checkCurrentLocation: enabled,
      immediateReminderId: reminder.id,
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await _loadPermissionSnapshot();
    await _loadReminders();
    await _loadTestAccess();
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadPermissionSnapshot();
      _loadReminders();
    } else if (index == 1) {
      _loadTestAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = _selectedIndex > (_showTestTab ? 2 : 1)
        ? 1
        : _selectedIndex;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const _SpatialBackdrop(),
          Positioned.fill(
            child: _selectedIndex == 0
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
                                _PrettyFilterBar(
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
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
                                          '确定删除“${reminder.locationName}”吗？删除后可在回收站还原。',
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
                : _selectedIndex == 1
                ? ProfileScreen(onProfileChanged: _loadTestAccess)
                : const TestScreen(),
          ),
        ],
      ),
      bottomNavigationBar: _GlassNavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: _selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '事件',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '个人',
          ),
          if (_showTestTab)
            const NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: '测试',
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

class _SpatialBackdrop extends StatelessWidget {
  const _SpatialBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFEFF7F4), Color(0xFFFFFBF3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 88,
              right: -46,
              child: Transform.rotate(
                angle: -0.22,
                child: _DepthPlane(
                  width: 180,
                  height: 96,
                  color: Color(0x3338BDF8),
                ),
              ),
            ),
            Positioned(
              top: 186,
              right: 64,
              child: Transform.rotate(
                angle: 0.34,
                child: _DepthPlane(
                  width: 88,
                  height: 88,
                  color: Color(0x1A2563EB),
                ),
              ),
            ),
            Positioned(
              top: 312,
              left: -58,
              child: Transform.rotate(
                angle: 0.2,
                child: _DepthPlane(
                  width: 190,
                  height: 112,
                  color: Color(0x24F59E0B),
                ),
              ),
            ),
            Positioned(
              bottom: 254,
              left: 48,
              child: Transform.rotate(
                angle: -0.36,
                child: _DepthPlane(
                  width: 96,
                  height: 54,
                  color: Color(0x1A7C3AED),
                ),
              ),
            ),
            Positioned(
              bottom: 108,
              right: 22,
              child: Transform.rotate(
                angle: 0.16,
                child: _DepthPlane(
                  width: 132,
                  height: 72,
                  color: Color(0x1F10B981),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepthPlane extends StatelessWidget {
  const _DepthPlane({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
      ),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(46, 0, 46, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.66),
                  Colors.white.withValues(alpha: 0.38),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A10203F),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
                BoxShadow(
                  color: Color(0x22FFFFFF),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              height: 62,
              elevation: 0,
              selectedIndex: selectedIndex,
              backgroundColor: Colors.transparent,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
          ),
        ),
      ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302563EB),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x16F59E0B),
            blurRadius: 18,
            offset: Offset(-8, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB),
                    Color(0xFF0F766E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
            ),
            Positioned(
              right: 18,
              top: -26,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 108,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x162563EB),
            blurRadius: 20,
            offset: Offset(0, 10),
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

class _PrettyFilterBar extends StatelessWidget {
  const _PrettyFilterBar({required this.value, required this.onChanged});

  final _ReminderFilter value;
  final ValueChanged<_ReminderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142563EB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _FilterChipButton(
            selected: value == _ReminderFilter.all,
            icon: Icons.inbox_outlined,
            label: '全部',
            onTap: () => onChanged(_ReminderFilter.all),
          ),
          _FilterChipButton(
            selected: value == _ReminderFilter.active,
            icon: Icons.notifications_active_outlined,
            label: '生效',
            onTap: () => onChanged(_ReminderFilter.active),
          ),
          _FilterChipButton(
            selected: value == _ReminderFilter.paused,
            icon: Icons.pause_circle_outline,
            label: '暂停',
            onTap: () => onChanged(_ReminderFilter.paused),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF60708F);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFEAF1FF), Color(0xFFF0FBF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1C2563EB),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
