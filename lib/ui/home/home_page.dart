import 'dart:async';

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
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/settings_tiles.dart';
import '../schedule/day_actions.dart';
import '../schedule/marks.dart';
import '../schedule/rest_day.dart';
import '../settings/settings_button.dart';
import 'day_card.dart';

/// Главная: всё важное на сегодня на одном экране. Карточка дня (что идёт, что дальше, сколько осталось),
/// сводки по оценкам и пропускам, завтрашний день, неделя одним взглядом и последние оценки.
/// Любой блок открывает нужный раздел одним нажатием.
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final day = dateOnly(now);
    final slots = _st?.schedule?.slots ?? const <LessonSlot>[];

    return LargePage(
      title: _greeting(now.hour),
      subtitle: '${weekdayName(day)}, ${fullDate(day)}',
      actions: const [SettingsButton(), SizedBox(width: 4)],
      onRefresh: () => _load(force: true),
      slivers: [
        Inset(children: [
          Smooth(child: KeyedSubtree(key: ValueKey('today-${_st?.status.name}'), child: _today(context, store, day))),
          MarksSection(date: day, store: store, slots: slots),
          _Tiles(store: store, onTab: widget.onTab),
          const SizedBox(height: 12),
          _Tomorrow(store: store, date: addDays(day, 1), onDay: widget.onDay),
          const SectionHeader('Эта неделя'),
          _Week(store: store, today: day, onDay: widget.onDay),
          _Recent(store: store, onTab: widget.onTab),
        ]),
      ],
    );
  }

  Widget _today(BuildContext context, AppStore store, DateTime day) {
    final st = _st;
    if (st == null) {
      return Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.cs.surfaceContainerLow, borderRadius: BorderRadius.circular(32)),
        child: const CircularProgressIndicator(),
      );
    }
    switch (st.status) {
      case DayStatus.ok:
        return DayCard(
          date: day,
          slots: st.schedule!.slots,
          profile: store.bellProfileFor(day),
          store: store,
          onShortDay: () => toggleShortDay(context, store, day),
          onMark: () {
            Haptics.selection();
            showMarkSheet(context, day);
          },
        );
      case DayStatus.sunday:
        return RestDay(
          date: day,
          store: store,
          onJump: widget.onDay,
          icon: Icons.wb_sunny_rounded,
          title: 'Сегодня выходной',
          message: 'Пар нет, можно отдохнуть.',
          recap: true,
        );
      case DayStatus.noGroup:
        return RestDay(
          date: day,
          store: store,
          onJump: widget.onDay,
          icon: Icons.search_off_rounded,
          title: 'Расписание не найдено',
          message: 'Для группы ${store.settings.group} на сегодня занятий нет.',
        );
      case DayStatus.notPublished:
        return const EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: 'Расписание пока отсутствует',
          message: 'Колледж публикует расписание только на ближайшие дни. Потяните вниз, чтобы проверить ещё раз.',
        );
      case DayStatus.offline:
      case DayStatus.error:
        return EmptyState(
          icon: st.status == DayStatus.offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          title: 'Не удалось загрузить',
          message: st.note ?? 'Проверьте подключение и попробуйте ещё раз.',
          action: FilledButton.tonal(onPressed: () => _load(force: true), child: const Text('Повторить')),
        );
    }
  }
}

/// Две плитки рядом: средний балл и пропуски месяца. У каждой свой цвет по состоянию дел.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.store, required this.onTab});
  final AppStore store;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final avg = GradeStats.of(store.grades).average;
    final hours = monthUnexcusedHours(store.absences, DateTime.now());
    final level = limitLevel(hours, warnFrom: kMonthWarnFrom, limit: kMonthLimit);
    final absTone = switch (level) {
      LimitLevel.ok => hueTone(context, kHueGreen),
      LimitLevel.near => hueTone(context, kHueAmber),
      LimitLevel.reached => hueTone(context, 4),
    };
    final gradeT = avg == null ? hueTone(context, kHueBlue) : gradeTone(context, avg);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _StatTile(
            tone: gradeT,
            icon: Icons.star_rounded,
            label: 'Средний балл',
            value: avg == null ? '—' : fmtAvg(avg),
            sub: store.grades.isEmpty ? 'Оценок пока нет' : gradesText(store.grades.length),
            progress: avg == null ? 0 : avg / 10,
            onTap: () => onTab(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            tone: absTone,
            icon: Icons.event_busy_rounded,
            label: 'Пропуски',
            value: '$hours из $kMonthLimit ч',
            sub: hours == 0 ? 'Пропусков нет' : 'Без уважительной',
            progress: hours / kMonthLimit,
            onTap: () => onTab(3),
          ),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.tone, required this.icon, required this.label, required this.value, required this.sub, required this.progress, required this.onTap});
  final Tone tone;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return SegmentCard(
      index: 0,
      count: 1,
      color: tone.bg,
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: tone.fg),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: tt.labelLarge?.copyWith(color: tone.fg, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Text(value, style: tt.headlineSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 2),
          Text(sub, style: tt.bodySmall?.copyWith(color: tone.fg.withValues(alpha: 0.85))),
          const SizedBox(height: 12),
          Bar(value: progress.clamp(0.0, 1.0).toDouble(), color: tone.fg, height: 8, track: tone.fg.withValues(alpha: 0.16)),
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
    return SegmentCard(
      index: 0,
      count: 1,
      onTap: () {
        Haptics.selection();
        onDay(date);
      },
      child: BadgeRow(icon: Icons.event_rounded, tone: tone, title: title, subtitle: sub),
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
    final cs = context.cs;
    final tt = context.tt;
    if (store.grades.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader('Оценки'),
        SegmentCard(
          index: 0,
          count: 1,
          onTap: () => showGradeSheet(context),
          child: BadgeRow(
            icon: Icons.add_rounded,
            tone: hueTone(context, kHueAmber),
            title: 'Добавьте первую оценку',
            subtitle: 'Приложение посчитает средний балл по каждому предмету',
          ),
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
      for (var i = 0; i < shown.length; i++)
        SegmentCard(
          index: i,
          count: shown.length,
          onTap: () {
            Haptics.selection();
            onTab(2);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              NumberBadge('${shown[i].value}', tone: gradeTone(context, shown[i].value), size: 46, round: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.subjectName(shown[i].subject), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                  Text(
                    [longDate(shown[i].date), if (shown[i].kind.isNotEmpty) shown[i].kind].join(' · '),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}
