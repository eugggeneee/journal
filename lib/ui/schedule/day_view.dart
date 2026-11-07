import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../../logic/schedule/schedule_service.dart';
import '../absences/absence_actions.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/edge_fade.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'day_summary.dart';
import 'day_timeline.dart';
import 'marks.dart';
import 'now_card.dart';
import 'rest_day.dart';

/// Один день расписания: сводка, карточка «Сейчас», лента пар и состояния без пар.
class DayView extends StatefulWidget {
  const DayView({super.key, required this.date, required this.onJump});
  final DateTime date;

  /// Открыть другой день (например, ближайший учебный из карточки выходного).
  final ValueChanged<DateTime> onJump;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  DayState? _st;
  bool _started = false;
  int _gen = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Сегодня: раз в полминуты обновляем карточку «Сейчас» и шкалу дня.
    if (sameDay(widget.date, today())) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final store = StoreScope.of(context);
    final repo = StoreScope.repoOf(context);
    final gen = ++_gen;
    final cached = store.cachedSchedule(store.settings.group, widget.date);
    if (cached != null && _st == null) _st = DayState(DayStatus.ok, schedule: cached, fromCache: true);
    final st = await repo.load(widget.date, force: force);
    if (!mounted || gen != _gen) return;
    setState(() => _st = st);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final st = _st;
    final slots = st?.schedule?.slots ?? const <LessonSlot>[];
    final Widget content = st == null
        ? const Padding(key: ValueKey('day-loading'), padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
        : KeyedSubtree(key: ValueKey('day-${st.status.name}'), child: _content(context, store, st));
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: EdgeFade(
        top: 14,
        bottom: 28,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kFabClearance),
          children: [
            if (st != null && st.status != DayStatus.ok) _chips(context),
            MarksSection(date: widget.date, store: store, slots: slots),
            Smooth(child: content),
          ],
        ),
      ),
    );
  }

  /// Кнопки дня без пар: пометка (ОКР, зачёт, практика, сокращённый день или своя).
  Widget _chips(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(
            avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Пометка'),
            onPressed: () {
              Haptics.selection();
              showMarkSheet(context, widget.date);
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.timelapse_rounded, size: 18),
            label: const Text('Сокращённый день'),
            onPressed: () => _markShortDay(context),
          ),
        ]),
      );

  /// Шаблон пометки на весь день «Сокращённый день»: ставится одним нажатием, повторное — снимает.
  void _markShortDay(BuildContext context) {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final date = widget.date;
    final before = store.snapshotMarks(date);
    final existing = store.markFor(date, 0);
    Haptics.selection();
    if (existing != null && existing.label == kShortDayMark) {
      store.deleteMark(existing.id);
      showUndo(messenger, 'Пометка снята', () => store.restoreMarks(date, before));
    } else {
      store.saveMark(DayMark(id: existing?.id ?? newId(), date: date, lesson: 0, label: kShortDayMark));
      showUndo(messenger, 'Сокращённый день отмечен', () => store.restoreMarks(date, before));
    }
  }

  Widget _content(BuildContext context, AppStore store, DayState st) {
    final cs = context.cs;
    switch (st.status) {
      case DayStatus.ok:
        final s = st.schedule!;
        final date = widget.date;
        final profile = store.bellProfileFor(date);
        final now = DateTime.now();
        final minute = now.hour * 60 + now.minute;
        final isToday = sameDay(date, today());
        final status = st.note ?? (st.fromCache ? 'Сохранено на устройстве' : 'Обновлено в ${hhmm(s.fetchedAt)}');
        final marked = [for (final slot in s.slots) if (store.absenceFor(date, slot.number) != null) slot];
        final allMarked = marked.length == s.slots.length && s.slots.isNotEmpty;
        final hours = marked.fold<int>(0, (a, slot) => a + (store.absenceFor(date, slot.number)?.hours ?? 0));

        final bells = [for (final slot in s.slots) profile[slot.number]].whereType<BellSlot>().toList();
        String? range;
        if (bells.isNotEmpty) {
          final from = bells.map((b) => b.start).reduce((a, b) => a < b ? a : b);
          final to = bells.map((b) => b.end).reduce((a, b) => a > b ? a : b);
          range = shortRange(from, to);
          if (isToday && minute >= from && minute < to) range = '$range · осталось ${spanText(to - minute)}';
        }
        final clock = isToday ? dayClock(profile, [for (final slot in s.slots) slot.number], minute) : null;
        final statusIcon = st.note != null
            ? Icons.info_outline_rounded
            : (st.fromCache ? Icons.download_done_rounded : Icons.cloud_done_rounded);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DaySummary(
            pairs: s.slots.length,
            hours: hours,
            subtitle: range ?? status,
            allMarked: allMarked,
            shortDay: store.markFor(date, 0)?.label == kShortDayMark,
            onWholeDay: () => toggleWholeDay(context, store, date, s.slots),
            onShortDay: () => _markShortDay(context),
            onMark: () {
              Haptics.selection();
              showMarkSheet(context, date);
            },
          ),
          if (clock != null && clock.phase != DayPhase.none)
            NowCard(clock: clock, slots: s.slots, profile: profile, store: store),
          DayTimeline(date: date, slots: s.slots, store: store),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(statusIcon, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
            ]),
          ),
        ]);
      case DayStatus.sunday:
        return RestDay(
          date: widget.date,
          store: store,
          onJump: widget.onJump,
          icon: Icons.wb_sunny_rounded,
          title: 'Выходной',
          message: 'В этот день пар нет, можно отдохнуть.',
          recap: true,
        );
      case DayStatus.noGroup:
        return RestDay(
          date: widget.date,
          store: store,
          onJump: widget.onJump,
          icon: Icons.search_off_rounded,
          title: 'Расписание не найдено',
          message: 'Для группы ${store.settings.group} на эту дату занятий нет.',
        );
      case DayStatus.notPublished:
        final future = !widget.date.isBefore(today());
        return EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: 'Расписание пока отсутствует',
          message: future
              ? 'Колледж публикует расписание только на ближайшие дни. Потяните вниз, чтобы проверить ещё раз.'
              : 'Этот день не был сохранён на устройстве, а на сайте старые расписания не хранятся.',
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
