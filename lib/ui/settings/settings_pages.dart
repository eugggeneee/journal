import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../logic/limits.dart';
import '../app/scope.dart';
import '../kit/components/edge_fade.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/selectors.dart';
import '../kit/inputs/settings_tiles.dart';
import '../kit/sheets/sheet.dart';
import 'bells_page.dart';
import 'group_picker.dart';

/// Каркас вложенной страницы настроек: крупный заголовок и содержимое.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.cs.surface,
        body: ContentFrame(
          child: EdgeFade(top: 0, child: CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(title)),
              Inset(children: children),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          )),
        ),
      );
}

// ───────────────────────── Расписание ─────────────────────────

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
  ];
  return parts.join(' · ');
}

// ───────────────────────── Пропуски ─────────────────────────

class AbsenceSettingsPage extends StatelessWidget {
  const AbsenceSettingsPage({super.key});

  Future<void> _end(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = today();
    final sem = store.semesterOn(t);
    final ok = await confirmDialog(
      context,
      title: 'Завершить 1-й семестр?',
      message: 'С ${fullDate(t)} начнётся 2-й семестр: счётчик в $kSemesterLimit часов начнётся заново и закончится '
          '1 августа ${sem.year + 1}. Пропуски 1-го семестра останутся в журнале.',
      confirmLabel: 'Завершить',
    );
    if (!ok || !context.mounted) return;
    if (!store.endFirstSemester(t)) return;
    Haptics.medium();
    showUndo(messenger, 'Начался 2-й семестр', () => store.reopenFirstSemester(sem.year));
  }

  Future<void> _reopen(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sem = store.semesterOn();
    final split = semesterSplit(sem.year, store.settings.semesterSplits);
    final ok = await confirmDialog(
      context,
      title: 'Вернуть 1-й семестр?',
      message: 'Завершение 1-го семестра отменится, а пропуски 2-го семестра снова будут считаться в 1-м.',
      confirmLabel: 'Вернуть',
      destructive: true,
    );
    if (!ok || !context.mounted || split == null) return;
    store.reopenFirstSemester(sem.year);
    Haptics.medium();
    showUndo(messenger, '1-й семестр возвращён', () => store.endFirstSemester(split));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final now = DateTime.now();
    final sem = store.semesterOn(now);
    final hours = semesterUnexcusedHours(store.absences, sem);
    final month = monthUnexcusedHours(store.absences, now);
    final canEnd = canEndSemester(now, store.settings.semesterSplits);
    final second = sem.number == 2;
    final tone = Tone(cs.secondaryContainer, cs.onSecondaryContainer);

    final String period;
    if (sem.upcoming) {
      period = 'Каникулы. ${sem.title} начнётся ${fullDate(sem.start)}.';
    } else if (second) {
      period = 'Идёт с ${fullDate(sem.start)} и закончится ${fullDate(sem.end)}.';
    } else {
      period = 'Идёт с ${fullDate(sem.start)}. Закончится, когда вы нажмёте кнопку ниже.';
    }

    return SettingsScaffold(title: 'Пропуски', children: [
      const SectionHeader('Быстрый пропуск', top: 0),
      const HoursSelector(),
      const SectionHeader('Семестр'),
      Appear(
        index: 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sem.title, style: context.tt.titleLarge?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
                  Text('Учебный год ${sem.years}', style: context.tt.bodyMedium?.copyWith(color: tone.fg.withValues(alpha: 0.85))),
                ]),
              ),
              Text('$hours / $kSemesterLimit ч', style: context.tt.titleMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: hours / kSemesterLimit),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Bar(
                value: v,
                color: hours >= kSemesterLimit ? absenceAccent(context, excused: false) : cs.primary,
                track: tone.fg.withValues(alpha: 0.14),
              ),
            ),
            const SizedBox(height: 12),
            Text(period, style: context.tt.bodyMedium?.copyWith(color: tone.fg, height: 1.35)),
            Smooth(
              child: canEnd
                  ? Padding(
                      key: const ValueKey('end'),
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('Завершить 1-й семестр'),
                        onPressed: () => _end(context),
                      ),
                    )
                  : second
                      ? Padding(
                          key: const ValueKey('reopen'),
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Вернуть 1-й семестр'),
                            onPressed: () => _reopen(context),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ]),
        ),
      ),
      const SectionHeader('Лимиты'),
      SegmentCard(
        index: 0,
        count: 2,
        child: SettingsTile(
          icon: Icons.calendar_month_rounded,
          title: 'В месяц: $kMonthLimit ч',
          subtitle: 'Сейчас $month ч без уважительной. Счётчик обнуляется с 1-го числа каждого месяца',
        ),
      ),
      SegmentCard(
        index: 1,
        count: 2,
        child: SettingsTile(
          icon: Icons.school_rounded,
          title: 'В семестр: $kSemesterLimit ч',
          subtitle: 'Предупреждение с $kSemesterWarnFrom ч без уважительной причины',
        ),
      ),
    ]);
  }
}

// ───────────────────────── Поведение ─────────────────────────

class BehaviorSettingsPage extends StatelessWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    return SettingsScaffold(title: 'Поведение', children: [
      SegmentCard(
        index: 0,
        count: 1,
        onTap: () => store.setHaptics(!s.haptics),
        child: SettingsTile(
          icon: Icons.vibration_rounded,
          title: 'Виброотклик',
          subtitle: 'Лёгкая вибрация при нажатиях и отметках',
          trailing: SettingsSwitch(value: s.haptics, onChanged: store.setHaptics),
        ),
      ),
    ]);
  }
}

// ───────────────────────── Данные ─────────────────────────

class DataSettingsPage extends StatelessWidget {
  const DataSettingsPage({super.key});

  Future<void> _export(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    Haptics.medium();
    showNote(messenger, 'Копия в буфере обмена — сохраните её в заметках');
  }

  Future<void> _import(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      await infoDialog(context, 'Буфер обмена пуст', 'Сначала скопируйте текст резервной копии.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Восстановить данные?',
      message: 'Текущие оценки, пропуски, пометки и звонки будут заменены данными из копии.',
      confirmLabel: 'Восстановить',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = store.importJson(text);
    if (err != null) {
      await infoDialog(context, 'Ошибка', err);
    } else {
      showNote(messenger, 'Данные восстановлены');
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(title: 'Данные', children: [
        SegmentCard(
          index: 0,
          count: 2,
          onTap: () => _export(context),
          child: const SettingsTile(
            icon: Icons.content_copy_rounded,
            title: 'Сохранить копию',
            subtitle: 'Оценки, пропуски, пометки и звонки — в буфер обмена',
          ),
        ),
        SegmentCard(
          index: 1,
          count: 2,
          onTap: () => _import(context),
          child: const SettingsTile(
            icon: Icons.restore_rounded,
            title: 'Восстановить из копии',
            subtitle: 'Вставить данные из буфера обмена',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: Text(
            'Оценки, пропуски и пометки хранятся только на этом устройстве. Расписание берётся с сайта bseumtc.by.',
            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant, height: 1.4),
          ),
        ),
      ]);
}
