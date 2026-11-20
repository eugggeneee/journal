import 'dart:async';

import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/limits.dart';
import '../../logic/schedule/schedule_service.dart';
import '../app/scope.dart';
import '../grades/grade_sheet.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/gesture_guide.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/sheet.dart';
import '../schedule/marks.dart';
import '../settings/settings_button.dart';
import '../settings/group_picker.dart';
import '../tasks/task_sheet.dart';
import '../tasks/task_tile.dart';
import '../tasks/tasks_page.dart';
import 'day_card.dart';
import 'day_metrics.dart';
import 'hero_surface.dart';

/// Главная: один цельный экран. Сверху цветной блок на всю ширину с приветствием и состоянием дня (что идёт,
/// сколько осталось, что дальше), ниже без карточек и рамок: показатели, завтра, неделя и последние оценки,
/// разделённые тонкими линиями. Любой блок открывает нужный раздел одним нажатием.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onTab, required this.onDay});

  /// Открыть вкладку по номеру.
  final ValueChanged<int> onTab;

  /// Открыть день в расписании.
  final ValueChanged<DateTime> onDay;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  DayState? _st;
  String? _loadedGroup;
  int _gen = 0;
  final _scroll = ScrollController();
  Timer? _tick;
  late DateTime _day = today();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Раз в полминуты обновляем карточку дня: оставшееся время и шкала идут сами.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (!sameDay(_day, today())) {
        setState(() {
          _day = today();
          _st = null;
        });
        _load();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = StoreScope.of(context).settings.group;
    if (_loadedGroup == group) return;
    _loadedGroup = group;
    _st = null;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (!sameDay(_day, today()))
      setState(() {
        _day = today();
        _st = null;
      });
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final store = StoreScope.of(context);
    final repo = StoreScope.repoOf(context);
    final gen = ++_gen;
    final date = _day;
    final cached = store.cachedSchedule(store.settings.group, date);
    if (cached != null && _st == null) _st = DayState(DayStatus.ok, schedule: cached, fromCache: true);
    final st = await repo.load(date, force: force);
    if (!mounted || gen != _gen) return;
    setState(() => _st = st);
  }

  Widget _header(BuildContext context, Color fg, DateTime now, {bool hasLessonActions = false}) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: LayoutBuilder(
              builder: (context, box) {
                final date = longDate(now);
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    box.maxWidth < MediaQuery.textScalerOf(context).scale(140) ? date.replaceFirst(', ', ',\n') : date,
                    style: context.tt.titleMedium?.copyWith(color: fg, fontWeight: JournalType.emphasis),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: fg, backgroundColor: fg.withValues(alpha: .1)),
          onPressed: () => openGroupPicker(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Text(StoreScope.of(context).settings.group, style: context.tt.labelLarge?.copyWith(color: fg)),
          ),
        ),
        if (!hasLessonActions)
          IconButton(
            tooltip: 'Добавить оценку',
            color: fg,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showGradeSheet(context),
          ),
        SettingsButton(color: fg),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final day = dateOnly(now);
    final slots = _st?.schedule?.slots ?? const <LessonSlot>[];

    // Блоки идут в порядке, который выбрал пользователь, скрытые пропускаются. Между блоками тонкая линия.
    final shown = [
      for (final b in store.settings.homeOrder)
        if (b != kBlockMetrics && !store.settings.homeHidden.contains(b)) b,
    ];
    Widget block(String id) => switch (id) {
      kBlockTasks => _TasksBlock(store: store),
      kBlockTomorrow => _Tomorrow(store: store, date: addDays(day, 1), onDay: widget.onDay),
      kBlockWeek => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Эта неделя'),
          _Week(store: store, today: day, onDay: widget.onDay),
          const SizedBox(height: 8),
        ],
      ),
      _ => _Recent(store: store, onTab: widget.onTab),
    };
    final sections = <Widget>[
      Smooth(
        child: store.settings.tipGestures
            ? const SizedBox(key: ValueKey('tip-none'), width: double.infinity)
            : _GestureTip(key: const ValueKey('tip'), store: store),
      ),
      MarksSection(date: day, store: store, slots: slots),
      _LimitNote(store: store, onTab: widget.onTab),
      for (var i = 0; i < shown.length; i++) ...[if (i > 0) const _Hairline(), block(shown[i])],
      if (shown.isEmpty && store.settings.homeHidden.contains(kBlockMetrics))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Все блоки скрыты. Вернуть их можно в настройках, раздел «Главная».',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ),
    ];

    final heroColor = context.cs.primaryContainer;
    final bodyColor = context.cs.surface;
    return ContentFrame(
      child: LayoutBuilder(
        builder: (context, viewport) => AnimatedBuilder(
          animation: _scroll,
          builder: (context, child) {
            final pulling = _scroll.hasClients && _scroll.offset < 0;
            final background = pulling ? heroColor : bodyColor;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayForSurface(background),
              child: ColoredBox(color: background, child: child),
            );
          },
          child: RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: () => _load(force: true),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: ColoredBox(color: bodyColor, child: _hero(context, store, day, now, viewport.maxHeight)),
                  ),
                  DecoratedSliver(
                    decoration: BoxDecoration(color: bodyColor),
                    sliver: SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          for (var i = 0; i < sections.length; i++) Appear(index: i + 1, child: sections[i]),
                        ]),
                      ),
                    ),
                  ),
                  SliverFillRemaining(hasScrollBody: false, fillOverscroll: true, child: ColoredBox(color: bodyColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, AppStore store, DateTime day, DateTime now, double viewportHeight) {
    final cs = context.cs;
    final tt = context.tt;
    Widget hdr(Color fg) => _header(context, fg, now);
    final calm = Tone(cs.primaryContainer, cs.onPrimaryContainer);
    final showMetrics = !store.settings.homeHidden.contains(kBlockMetrics);
    Widget metrics(Tone tone, bool compact) => DayMetrics(store: store, onTab: widget.onTab, tone: tone, compact: compact);
    final st = _st;
    if (st == null) {
      return HeroSurface(
        tone: calm,
        header: hdr,
        footer: showMetrics ? metrics(calm, true) : null,
        child: SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator(color: calm.fg)),
        ),
      );
    }
    if (st.status == DayStatus.ok) {
      return DayCard(
        viewportHeight: viewportHeight,
        metrics: showMetrics ? metrics : null,
        now: now,
        onOpenDay: () => widget.onDay(day),
        slots: st.schedule!.slots,
        profile: store.bellProfileFor(day),
        store: store,
        header: (fg, active) => _header(context, fg, now, hasLessonActions: active),
      );
    }
    final (IconData icon, String title, String message, bool retry) = switch (st.status) {
      DayStatus.sunday => (Icons.wb_sunny_rounded, 'Сегодня выходной', 'Пар нет, можно отдохнуть.', false),
      DayStatus.noGroup => (
        Icons.search_off_rounded,
        'Расписание не найдено',
        'Для группы ${store.settings.group} на сегодня занятий нет.',
        false,
      ),
      DayStatus.notPublished => (
        Icons.hourglass_empty_rounded,
        'Расписание пока отсутствует',
        'Колледж публикует расписание только на ближайшие дни. Потяните вниз, чтобы проверить ещё раз.',
        false,
      ),
      DayStatus.offline => (
        Icons.wifi_off_rounded,
        'Не удалось загрузить',
        st.note ?? 'Проверьте подключение и попробуйте ещё раз.',
        true,
      ),
      _ => (
        Icons.error_outline_rounded,
        'Не удалось загрузить',
        st.note ?? 'Что-то пошло не так. Попробуйте ещё раз.',
        true,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroSurface(
          tone: calm,
          header: hdr,
          footer: showMetrics ? metrics(calm, true) : null,
          child: Row(
            children: [
              IconBox(icon: icon, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleLarge?.copyWith(color: calm.fg, fontWeight: JournalType.heading),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              if (retry)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonal(onPressed: () => _load(force: true), child: const Text('Повторить')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Тонкая разделительная линия между блоками главной.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Divider(height: 1, thickness: 1, color: context.cs.outlineVariant.withValues(alpha: 0.6)));
}

/// Завтра: сколько пар и когда начало. Берётся из сохранённых расписаний, без ожидания сети.
class _Tomorrow extends StatelessWidget {
  const _Tomorrow({required this.store, required this.date, required this.onDay});
  final AppStore store;
  final DateTime date;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final sched = store.cachedSchedule(store.settings.group, date);
    String title;
    String sub;
    if (date.weekday == DateTime.sunday) {
      title = 'Завтра выходной';
      sub = 'Пар нет, можно отдохнуть';
    } else if (sched == null || sched.slots.isEmpty) {
      title = 'Завтра · ${weekdayName(date).toLowerCase()}';
      sub = 'Расписание ещё не загружено';
    } else {
      final profile = store.bellProfileFor(date);
      final first = [...sched.slots]..sort((a, b) => a.number.compareTo(b.number));
      final bell = profile[first.first.number];
      title = 'Завтра · ${pairsText(sched.slots.length)}';
      final name = first.first.subjects.map(store.subjectName).join(' / ');
      sub = [if (bell != null) 'с ${fmtMin(bell.start)}', name].join(' · ');
    }
    return JournalRow(
      padding: const EdgeInsets.symmetric(vertical: 10),
      leading: IconBox(icon: Icons.event_rounded),
      title: title,
      subtitle: sub,
      onTap: () => onDay(date),
    );
  }
}

/// Неделя одним взглядом: шесть учебных дней, у каждого число пар. Сегодняшний день выделен.
class _Week extends StatelessWidget {
  const _Week({required this.store, required this.today, required this.onDay});
  final AppStore store;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final monday = addDays(today, -(today.weekday - 1));
    final absentDays = <String>{for (final a in store.absences) ymd(a.date)};
    return Row(children: [
      for (var i = 0; i < 6; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Builder(builder: (context) {
            final d = addDays(monday, i);
            final sel = sameDay(d, today);
            final sched = store.cachedSchedule(store.settings.group, d);
            final n = sched?.slots.length;
            final bg = sel ? cs.primary : cs.surfaceContainerLow;
            final fg = sel ? cs.onPrimary : cs.onSurface;
            final muted = sel ? cs.onPrimary.withValues(alpha: 0.85) : cs.onSurfaceVariant;
            return Semantics(
              button: true,
              label: '${weekdayName(d)}, ${n == null ? 'расписание не загружено' : pairsText(n)}',
              excludeSemantics: true,
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Haptics.selection();
                    onDay(d);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(weekdayShort(d), style: tt.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${d.day}', style: tt.titleMedium?.copyWith(color: fg, fontWeight: JournalType.heading)),
                        const SizedBox(height: 4),
                        Text(n == null ? '–' : '$n', style: tt.labelLarge?.copyWith(color: sel ? cs.onPrimary : cs.primary, fontWeight: JournalType.heading)),
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: absentDays.contains(ymd(d)) ? (sel ? cs.onPrimary : absenceAccent(context, excused: false)) : Colors.transparent,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    ]);
  }
}

/// Последние оценки: три записи, нажатие открывает вкладку «Оценки». Без оценок: приглашение добавить первую.
class _Recent extends StatelessWidget {
  const _Recent({required this.store, required this.onTab});
  final AppStore store;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    if (store.grades.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader('Оценки'),
        JournalRow(
      padding: const EdgeInsets.symmetric(vertical: 10),
          leading: IconBox(icon: Icons.add_rounded),
          title: 'Добавьте первую оценку',
          subtitle: 'Приложение посчитает средний балл по каждому предмету',
          onTap: () => showGradeSheet(context),
        ),
      ]);
    }
    final list = [...store.grades]..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final shown = list.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Последние оценки', trailing: gradesText(store.grades.length)),
      for (final g in shown)
        JournalRow(
      padding: const EdgeInsets.symmetric(vertical: 10),
          leading: NumberBadge('${g.value}', tone: gradeTone(context, g.value), size: 46, round: false),
          title: store.subjectName(g.subject),
          subtitle: [longDate(g.date), if (g.kind.isNotEmpty) g.kind].join(' · '),
          onTap: () => onTab(2),
        ),
    ]);
  }
}

/// Предупреждение о лимите заранее: «До лимита месяца осталось 3 часа». Показывается, когда лимит близко
/// или достигнут (месяц и семестр), нажатие открывает «Пропуски».
class _LimitNote extends StatelessWidget {
  const _LimitNote({required this.store, required this.onTab});
  final AppStore store;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final now = DateTime.now();
    final semester = store.semesterOn(now);
    final month = monthUnexcusedHours(store.absences, now);
    final sem = semesterUnexcusedHours(store.absences, semester);
    final monthLevel = limitLevel(month, warnFrom: kMonthWarnFrom, limit: kMonthLimit);
    final semLevel = limitLevel(sem, warnFrom: kSemesterWarnFrom, limit: kSemesterLimit);

    final lines = <String>[
      if (monthLevel == LimitLevel.reached) 'Лимит месяца достигнут: $month из $kMonthLimit ч',
      if (monthLevel == LimitLevel.near) 'До лимита месяца осталось ${hoursText(kMonthLimit - month)}',
      if (semLevel == LimitLevel.reached) 'Лимит семестра достигнут: $sem из $kSemesterLimit ч',
      if (semLevel == LimitLevel.near) 'До лимита семестра осталось ${hoursText(kSemesterLimit - sem)}',
    ];
    final reached = monthLevel == LimitLevel.reached || semLevel == LimitLevel.reached;
    final tone = reached ? hueTone(context, 4) : hueTone(context, kHueAmber);

    return Smooth(
      child: lines.isEmpty
          ? const SizedBox(key: ValueKey('limit-none'), width: double.infinity)
          : Padding(
              key: ValueKey('limit-${lines.length}-$reached'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: tone.bg,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Haptics.selection();
                    onTab(3);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      IconBox(icon: reached ? Icons.error_rounded : Icons.warning_amber_rounded, size: 36, glyphSize: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final l in lines) Text(l, style: tt.titleSmall?.copyWith(color: tone.fg, fontWeight: JournalType.emphasis, height: 1.3)),
                          Text('Нажмите, чтобы открыть пропуски', style: tt.bodySmall?.copyWith(color: tone.fg.withValues(alpha: 0.85))),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: tone.fg),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Задания на главной: ближайшие три с отметкой «сделано». Заголовок напоминает о просроченном и сегодняшнем.
class _TasksBlock extends StatelessWidget {
  const _TasksBlock({required this.store});
  final AppStore store;

  void _openAll(BuildContext context) {
    Haptics.selection();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TasksPage()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final t = today();
    final open = store.openTasks;
    final overdue = open.where((x) => x.due.isBefore(t)).length;
    final dueToday = open.where((x) => sameDay(x.due, t)).length;

    String trailing;
    Color? trailingColor;
    if (overdue > 0) {
      trailing = 'Просрочено: $overdue';
      trailingColor = hueAccent(context, 4);
    } else if (dueToday > 0) {
      trailing = 'Сегодня: $dueToday';
      trailingColor = hueAccent(context, kHueAmber);
    } else {
      trailing = 'Все задания';
    }

    final Widget body;
    if (open.isEmpty) {
      body = JournalRow(
      padding: const EdgeInsets.symmetric(vertical: 10),
        leading: IconBox(icon: store.tasks.isEmpty ? Icons.add_task_rounded : Icons.task_alt_rounded),
        title: store.tasks.isEmpty ? 'Добавьте первое задание' : 'Всё сделано',
        subtitle: store.tasks.isEmpty ? 'Домашнее задание и заметки со сроком' : 'Невыполненных заданий нет',
        onTap: () => store.tasks.isEmpty ? showTaskSheet(context) : _openAll(context),
      );
    } else {
      final shown = open.take(3).toList();
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final task in shown)
          InkWell(
            key: ValueKey('home-task-${task.id}'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => showTaskSheet(context, edit: task),
            child: TaskSummary(task: task, store: store),
          ),
        if (open.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text('и ещё ${open.length - 3}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Задания', trailing: store.tasks.isEmpty ? null : trailing, trailingColor: trailingColor,
        onTap: store.tasks.isEmpty ? null : () => _openAll(context)),
      body,
    ]);
  }
}

/// Подсказка при первом запуске: одна строка про главный жест и ссылка на все жесты. Закрывается навсегда.
class _GestureTip extends StatelessWidget {
  const _GestureTip({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final tone = iconTone(context.cs);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_rounded, color: tone.fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Подсказка', style: tt.titleSmall?.copyWith(color: tone.fg, fontWeight: JournalType.heading)),
                const SizedBox(height: 2),
                Text(
                  'Коротко удержите пару в расписании, чтобы отметить пропуск, а смахните запись влево, чтобы удалить её.',
                  style: tt.bodyMedium?.copyWith(color: tone.fg.withValues(alpha: 0.9), height: 1.3),
                ),
              ]),
            ),
          ]),
          Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: tone.fg),
              onPressed: () {
                Haptics.selection();
                showAdaptiveSheet<void>(
                  context,
                  (_) => const SheetScaffold(title: 'Жесты', subtitle: 'Что делают нажатие, удержание и смахивание', children: [GestureGuide()]),
                );
              },
              child: const Text('Все жесты'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: tone.fg),
              onPressed: () {
                Haptics.selection();
                store.setTipGestures(true);
              },
              child: const Text('Понятно', style: TextStyle(fontWeight: JournalType.heading)),
            ),
          ]),
        ]),
      ),
    );
  }
}
