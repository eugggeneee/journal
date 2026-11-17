import 'dart:async';

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/limits.dart';
import '../../logic/schedule/schedule_service.dart';
import '../../logic/stats.dart';
import '../app/scope.dart';
import '../grades/grade_sheet.dart';
import '../kit/animation/reveal.dart';
import '../kit/animation/motion.dart';
import '../kit/components/gesture_guide.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/sheet.dart';
import '../schedule/day_actions.dart';
import '../schedule/marks.dart';
import '../settings/settings_button.dart';
import '../tasks/task_sheet.dart';
import '../tasks/task_tile.dart';
import '../tasks/tasks_page.dart';
import 'day_card.dart';
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
  bool _started = false;
  int _gen = 0;
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
        _day = today();
        _load();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _day = today();
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

  static String _greeting(int hour) {
    if (hour < 5) return 'Доброй ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  /// Шапка на цветном блоке: приветствие, дата и настройки. Слишком длинный текст уменьшается, а не обрезается.
  Widget _header(BuildContext context, Color fg, DateTime now) {
    final tt = context.tt;
    final day = dateOnly(now);
    return Row(children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_greeting(now.hour), maxLines: 1, softWrap: false, style: tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${weekdayName(day)}, ${fullDate(day)}', maxLines: 1, softWrap: false, style: tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.85))),
            ),
          ]),
        ),
      ),
      SettingsButton(color: fg),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final day = dateOnly(now);
    final slots = _st?.schedule?.slots ?? const <LessonSlot>[];

    // Блоки идут в порядке, который выбрал пользователь, скрытые пропускаются. Между блоками тонкая линия.
    final shown = [for (final b in store.settings.homeOrder) if (!store.settings.homeHidden.contains(b)) b];
    Widget block(String id) => switch (id) {
          kBlockMetrics => _Metrics(store: store, onTab: widget.onTab),
          kBlockTasks => _TasksBlock(store: store),
          kBlockTomorrow => _Tomorrow(store: store, date: addDays(day, 1), onDay: widget.onDay),
          kBlockWeek => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Heading('Эта неделя'),
              _Week(store: store, today: day, onDay: widget.onDay),
              const SizedBox(height: 8),
            ]),
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
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const _Hairline(),
        block(shown[i]),
      ],
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Все блоки скрыты. Вернуть их можно в настройках, раздел «Главная».',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ),
    ];

    final dark = context.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Строка состояния стоит на цветном блоке: значки подбираются под тему, а не под прошлый экран.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ContentFrame(
      child: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Smooth(child: KeyedSubtree(key: ValueKey('hero-${_st?.status.name}'), child: _hero(context, store, day, now))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, kFabClearance),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (var i = 0; i < sections.length; i++) Appear(index: i + 1, child: sections[i]),
                ]),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _hero(BuildContext context, AppStore store, DateTime day, DateTime now) {
    final cs = context.cs;
    final tt = context.tt;
    Widget hdr(Color fg) => _header(context, fg, now);
    final calm = Tone(cs.primaryContainer, cs.onPrimaryContainer);
    final st = _st;
    if (st == null) {
      return HeroSurface(
        tone: calm,
        header: hdr,
        child: SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: calm.fg))),
      );
    }
    if (st.status == DayStatus.ok) {
      return DayCard(
        date: day,
        slots: st.schedule!.slots,
        profile: store.bellProfileFor(day),
        store: store,
        header: hdr,
        onShortDay: () => toggleShortDay(context, store, day),
        onMark: () {
          Haptics.selection();
          showMarkSheet(context, day);
        },
      );
    }
    final (IconData icon, String title, String message, bool retry) = switch (st.status) {
      DayStatus.sunday => (Icons.wb_sunny_rounded, 'Сегодня выходной', 'Пар нет, можно отдохнуть.', false),
      DayStatus.noGroup => (Icons.search_off_rounded, 'Расписание не найдено', 'Для группы ${store.settings.group} на сегодня занятий нет.', false),
      DayStatus.notPublished => (Icons.hourglass_empty_rounded, 'Расписание пока отсутствует', 'Колледж публикует расписание только на ближайшие дни. Потяните вниз, чтобы проверить ещё раз.', false),
      DayStatus.offline => (Icons.wifi_off_rounded, 'Не удалось загрузить', st.note ?? 'Проверьте подключение и попробуйте ещё раз.', true),
      _ => (Icons.error_outline_rounded, 'Не удалось загрузить', st.note ?? 'Что-то пошло не так. Попробуйте ещё раз.', true),
    };
    return HeroSurface(
      tone: calm,
      header: hdr,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CookieIcon(icon: icon, size: 56, bg: cs.primary, fg: cs.onPrimary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tt.titleLarge?.copyWith(color: calm.fg, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(message, style: tt.bodyMedium?.copyWith(color: calm.fg.withValues(alpha: 0.85), height: 1.3)),
            if (retry)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.tonal(onPressed: () => _load(force: true), child: const Text('Повторить')),
              ),
          ]),
        ),
      ]),
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

/// Заголовок блока на главной: заголовок слева, подпись справа.
class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.trailing, this.trailingColor, this.onTap});
  final String title;
  final String? trailing;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text(title, style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800, letterSpacing: 0.2))),
        if (trailing != null)
          Text(trailing!, style: tt.labelLarge?.copyWith(color: trailingColor ?? cs.onSurfaceVariant, fontWeight: onTap == null ? null : FontWeight.w700)),
      ]),
    );
    return onTap == null ? row : InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: row);
  }
}

/// Строка без карточки: значок слева, текст, стрелка справа. Вся строка нажимается.
class _FlatRow extends StatelessWidget {
  const _FlatRow({required this.leading, required this.title, required this.subtitle, required this.onTap});
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
              if (subtitle.isNotEmpty) Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// Два показателя рядом, разделённые линией: средний балл и пропуски месяца. Цвет акцента по состоянию дел.
class _Metrics extends StatelessWidget {
  const _Metrics({required this.store, required this.onTab});
  final AppStore store;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final avg = GradeStats.of(store.grades).average;
    final hours = monthUnexcusedHours(store.absences, DateTime.now());
    final level = limitLevel(hours, warnFrom: kMonthWarnFrom, limit: kMonthLimit);
    final absAccent = switch (level) {
      LimitLevel.ok => hueAccent(context, kHueGreen),
      LimitLevel.near => hueAccent(context, kHueAmber),
      LimitLevel.reached => hueAccent(context, 4),
    };
    final gradeAccentColor = avg == null ? hueAccent(context, kHueBlue) : gradeAccent(context, avg);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: _Metric(
          accent: gradeAccentColor,
          icon: Icons.star_rounded,
          label: 'Средний балл',
          value: avg == null ? '—' : fmtAvg(avg),
          sub: store.grades.isEmpty ? 'Оценок пока нет' : gradesText(store.grades.length),
          progress: avg == null ? 0 : avg / 10,
          onTap: () => onTab(2),
        ),
      ),
      Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: cs.outlineVariant.withValues(alpha: 0.6)),
      Expanded(
        child: _Metric(
          accent: absAccent,
          icon: Icons.event_busy_rounded,
          label: 'Пропуски',
          value: '$hours из $kMonthLimit ч',
          sub: hours == 0 ? 'Пропусков нет' : (hours >= kMonthLimit ? 'Лимит достигнут' : 'До лимита ${kMonthLimit - hours} ч'),
          progress: hours / kMonthLimit,
          onTap: () => onTab(3),
        ),
      ),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.accent, required this.icon, required this.label, required this.value, required this.sub, required this.progress, required this.onTap});
  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    return InkWell(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Text(value, style: tt.headlineSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800, height: 1.1)),
          Text(sub, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0.0, 1.0).toDouble()),
            duration: context.motion(Motion.long),
            curve: Motion.standard,
            builder: (context, v, _) => Bar(value: v, color: accent, height: 8, track: accent.withValues(alpha: 0.18)),
          ),
        ]),
      ),
    );
  }
}

/// Завтра: сколько пар и когда начало. Берётся из сохранённых расписаний, без ожидания сети.
class _Tomorrow extends StatelessWidget {
  const _Tomorrow({required this.store, required this.date, required this.onDay});
  final AppStore store;
  final DateTime date;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final tone = hueTone(context, kHueViolet);
    final sched = store.cachedSchedule(store.settings.group, date);
    String title;
    String sub;
    if (date.weekday == DateTime.sunday) {
      title = 'Завтра выходной';
      sub = 'Пар нет, можно отдохнуть';
    } else if (sched == null || sched.slots.isEmpty) {
      title = 'Завтра · ${weekdayName(date).toLowerCase()}';
      sub = 'Расписание ещё не опубликовано';
    } else {
      final profile = store.bellProfileFor(date);
      final first = [...sched.slots]..sort((a, b) => a.number.compareTo(b.number));
      final bell = profile[first.first.number];
      title = 'Завтра · ${pairsText(sched.slots.length)}';
      final name = first.first.subjects.map(store.subjectName).join(' / ');
      sub = [if (bell != null) 'с ${fmtMin(bell.start)}', name].join(' · ');
    }
    return _FlatRow(
      leading: IconBox(icon: Icons.event_rounded, tone: tone),
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
                        Text('${d.day}', style: tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(n == null ? '–' : '$n', style: tt.labelLarge?.copyWith(color: sel ? cs.onPrimary : cs.primary, fontWeight: FontWeight.w800)),
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
      final tone = hueTone(context, kHueAmber);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Heading('Оценки'),
        _FlatRow(
          leading: IconBox(icon: Icons.add_rounded, tone: tone),
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
      _Heading('Последние оценки', trailing: gradesText(store.grades.length)),
      for (final g in shown)
        _FlatRow(
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
                      Icon(reached ? Icons.error_rounded : Icons.warning_amber_rounded, color: tone.fg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final l in lines) Text(l, style: tt.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w700, height: 1.3)),
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
      trailing = store.tasks.isEmpty ? 'Добавить' : 'Все задания';
    }

    final Widget body;
    if (open.isEmpty) {
      final tone = hueTone(context, kHueTeal);
      body = _FlatRow(
        leading: IconBox(icon: store.tasks.isEmpty ? Icons.add_task_rounded : Icons.task_alt_rounded, tone: tone),
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
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TaskCheck(
                done: task.done,
                onTap: () {
                  Haptics.selection();
                  store.toggleTask(task.id);
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(task.text, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Pill(dueText(task.due), tone: dueTone(context, task), icon: Icons.event_rounded),
                      if (task.subject.isNotEmpty) Text(store.subjectName(task.subject), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        if (open.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text('и ещё ${open.length - 3}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Heading('Задания', trailing: trailing, trailingColor: trailingColor, onTap: () => store.tasks.isEmpty ? showTaskSheet(context) : _openAll(context)),
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
    final tone = hueTone(context, kHueViolet);
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
                Text('Подсказка', style: tt.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
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
              child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      ),
    );
  }
}
