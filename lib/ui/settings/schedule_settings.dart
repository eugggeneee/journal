part of 'settings_pages.dart';

class ScheduleSettingsPage extends StatefulWidget {
  const ScheduleSettingsPage({super.key});
  @override
  State<ScheduleSettingsPage> createState() => _ScheduleSettingsPageState();
}

class _ScheduleSettingsPageState extends State<ScheduleSettingsPage> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = StoreScope.repoOf(context);
    setState(() => _refreshing = true);
    await repo.prefetch(force: true, respectSetting: false);
    if (!mounted) return;
    setState(() => _refreshing = false);
    showNote(messenger, 'Расписание обновлено');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final cached = store.schedulesFor(s.group).length;
    return SettingsScaffold(title: 'Расписание', children: [
      SegmentCard(
        index: 0,
        count: 1,
        onTap: () => openGroupPicker(context),
        child: SettingsTile(
          icon: Icons.groups_rounded,
          title: 'Группа ${s.group}',
          subtitle: 'Нажмите, чтобы сменить',
          trailing: Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant),
        ),
      ),
      const SectionHeader('Загрузка'),
      SegmentCard(
        index: 0,
        count: 2,
        onTap: _refreshing ? null : _refresh,
        child: SettingsTile(
          icon: Icons.refresh_rounded,
          title: _refreshing ? 'Обновляю…' : 'Обновить расписание',
          subtitle: 'Сохранено: ${daysText(cached)} на устройстве',
          trailing: _refreshing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
        ),
      ),
      SegmentCard(
        index: 1,
        count: 2,
        onTap: () {
          Haptics.selection();
          store.setAutoRefresh(!s.autoRefresh);
        },
        child: SettingsTile(
          icon: Icons.sync_rounded,
          title: 'Автообновление',
          subtitle: 'Подгружать расписание при запуске',
          trailing: SettingsSwitch(value: s.autoRefresh, onChanged: store.setAutoRefresh),
        ),
      ),
      const SectionHeader('Время пар'),
      SegmentCard(
        index: 0,
        count: 1,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BellsPage())),
        child: SettingsTile(
          icon: Icons.notifications_active_rounded,
          title: 'Звонки',
          subtitle: bellsSummary(store.settings),
          trailing: Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant),
        ),
      ),
    ]);
  }
}

/// Короткое описание заданных звонков для списка настроек.
String bellsSummary(Settings s) {
  final done = [for (final k in kBellKeys) if (!s.bell(k).isEmpty) k];
  if (done.isEmpty) return 'Время пар не задано';
  final week = s.bell(kBellWeek);
  final parts = <String>[
    if (!week.isEmpty) 'будни ${week.slots.length} пар',
    if (!s.bell(kBellSat).isEmpty) 'суббота',
    'сокращённый день',
  ];
  return parts.join(' · ');
}
