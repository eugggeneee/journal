import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../../logic/schedule/schedule_service.dart';
import '../app/scope.dart';
import '../kit/components/widgets.dart' show segmentRadius;
import '../kit/foundation/ctx.dart';
import 'calendar_grid.dart';
import 'lesson_card.dart';
import 'lesson_sheet.dart';
import 'marks.dart';

/// Все семь дней используют общую часовую сетку, в том числе при разных звонках.
class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.refresh,
    required this.selected,
    required this.onShift,
    required this.onOpenDay,
  });
  final DateTime selected;
  final int refresh;
  final ValueChanged<int> onShift;
  final ValueChanged<DateTime> onOpenDay;
  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  final _states = <DateTime, DayState>{};
  (DateTime, String, int)? _request;
  late final Timer _timer;
  int _generation = 0;
  DateTime get monday => addDays(widget.selected, 1 - widget.selected.weekday);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (dayDiff(today(), monday) >= 0 && dayDiff(today(), monday) < 7) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(WeekView old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    final store = StoreScope.of(context);
    final repo = StoreScope.repoOf(context);
    final key = (monday, store.settings.group, widget.refresh);
    if (_request == key) return;
    final force = _request != null && _request!.$3 != widget.refresh;
    final generation = ++_generation;
    _request = key;
    _states.clear();
    for (var i = 0; i < 7; i++) {
      final date = addDays(monday, i);
      if (date.weekday == DateTime.sunday) {
        _states[date] = const DayState(DayStatus.sunday);
        continue;
      }
      final cache = store.cachedSchedule(store.settings.group, date);
      if (cache != null) _states[date] = DayState(DayStatus.ok, schedule: cache, fromCache: true);
      repo.load(date, force: force).catchError((_) => const DayState(DayStatus.error)).then((state) {
        if (mounted && generation == _generation) setState(() => _states[date] = state);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final now = DateTime.now();
    final days = List.generate(7, (i) => addDays(monday, i));
    final todayIndex = days.indexWhere((d) => sameDay(d, now));
    final minute = now.hour * 60 + now.minute;
    final slots = [for (final d in days) _states[d]?.schedule?.slots ?? <LessonSlot>[]];
    final darker = [for (final day in slots) darkerLessons(day, store)];
    final bells = [
      for (var i = 0; i < days.length; i++)
        for (final s in slots[i]) ?store.bellFor(days[i], s.number),
    ];
    final start = bells.isEmpty ? 8 * 60 : bells.map((b) => b.start).reduce(math.min) ~/ 60 * 60;
    final end = bells.isEmpty ? 16 * 60 : ((bells.map((b) => b.end).reduce(math.max) + 59) ~/ 60) * 60;
    final scale = 1.35 * MediaQuery.textScalerOf(context).scale(12) / 12;
    final height = (end - start) * scale;
    Widget dayColumn(int i) => Expanded(
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            for (final slot in slots[i])
              if (store.bellFor(days[i], slot.number) case final bell?)
                Positioned(
                  left: 3,
                  right: 2,
                  top: (bell.start - start) * scale,
                  height: math.max(1, bell.minutes * scale - 2),
                  child: _WeekEvent(
                    date: days[i],
                    slot: slot,
                    darker: darker[i].contains(slot.number),
                    store: store,
                    live: i == todayIndex && minute >= bell.start && minute < bell.end,
                  ),
                ),
          ],
        ),
      ),
    );
    List<Widget> extras(int i) {
      final date = days[i];
      final state = _states[date];
      final notes = store.marksOn(date).where((m) => m.wholeDay || !slots[i].any((s) => s.number == m.lesson));
      final status = switch (state?.status) {
        null => 'Загрузка…',
        DayStatus.sunday => 'Выходной',
        DayStatus.noGroup => 'Нет пар',
        DayStatus.notPublished => 'Нет расписания',
        DayStatus.offline => 'Нет сети',
        DayStatus.error => 'Ошибка загрузки',
        _ => null,
      };
      Widget entry(String label, VoidCallback tap, {bool marked = false, Color? background}) => Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: background ?? (marked ? cs.tertiaryContainer : cs.surfaceContainer),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(color: marked ? cs.onTertiaryContainer : cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      );
      return [
        if (status != null) entry(status, () => widget.onOpenDay(date)),
        for (final mark in notes)
          entry(
            mark.wholeDay ? mark.label : '${mark.lesson} · ${mark.label}',
            () => showMarkSheet(context, date, edit: mark),
            marked: true,
          ),
        for (final s in slots[i].where((s) => store.bellFor(date, s.number) == null))
          entry(
            '${s.number} · ${s.subjects.map(store.subjectName).join(' / ')}',
            () => showLessonSheet(context, date, s),
            background: lessonSurface(context, darker[i].contains(s.number)),
          ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Предыдущая неделя',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => widget.onShift(-1),
              ),
              Expanded(
                child: Text(
                  '${shortDate(days.first)} – ${shortDate(days.last)}',
                  textAlign: TextAlign.center,
                  style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Следующая неделя',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => widget.onShift(1),
              ),
            ],
          ),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: calendarGutter),
                for (final d in days)
                  Expanded(
                    child: CalendarDate(
                      date: d,
                      selected: sameDay(d, widget.selected),
                      onTap: () => widget.onOpenDay(d),
                    ),
                  ),
              ],
            ),
          ),
          const CalendarDateDivider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: calendarGutter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('День', style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                      ),
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: extras(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CalendarBand(
                    start: start,
                    end: end,
                    columns: 7,
                    minute: minute,
                    todayColumn: todayIndex,
                    pixelsPerMinute: scale,
                    child: Row(children: [for (var i = 0; i < 7; i++) dayColumn(i)]),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekEvent extends StatelessWidget {
  const _WeekEvent({
    required this.date,
    required this.slot,
    required this.store,
    required this.live,
    required this.darker,
  });
  final DateTime date;
  final LessonSlot slot;
  final AppStore store;
  final bool live;
  final bool darker;

  @override
  Widget build(BuildContext context) {
    final bell = store.bellFor(date, slot.number)!;
    final absence = store.absenceFor(date, slot.number);
    final mark = store.markFor(date, slot.number);
    final tasks = store.tasksForLesson(date, slot.number);
    final name = slot.subjects.map(store.subjectName).join(' / ');
    final time = shortRange(bell.start, bell.end);
    final rooms = slot.entries.map((e) => LessonCard.roomText(e.room)).where((r) => r.isNotEmpty).toSet().join(' / ');
    final bg = lessonSurface(context, darker);
    final fg = context.cs.onSurface;
    final radius = segmentRadius(0, 1, outer: 20);
    final details = [
      time,
      if (rooms.isNotEmpty) rooms,
      if (mark != null) mark.label,
      if (absence != null) absence.excused ? 'По уважительной' : 'Пропуск',
      if (tasks.isNotEmpty) 'Заданий: ${tasks.length}',
    ];
    return Semantics(
      button: true,
      label: [longDate(date), name, ...details].join(', '),
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showLessonSheet(context, date, slot),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: radius, border: live ? Border.all(color: context.cs.outline, width: 2) : null),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 6, 6),
              child: LayoutBuilder(
                builder: (context, box) {
                  final titleStyle = context.tt.bodySmall!.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  );
                  final lineHeight = MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) * 1.25;
                  final lines = (box.maxHeight / lineHeight).floor();
                  if (lines < 1) return const SizedBox.shrink();
                  final titleLines = lines >= 3 ? math.min(3, lines - 1) : 1;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: titleLines,
                        fit: FlexFit.loose,
                        child: Text(name, maxLines: titleLines, overflow: TextOverflow.ellipsis, style: titleStyle),
                      ),
                      if (lines > titleLines)
                        Flexible(
                          flex: lines - titleLines,
                          child: Text(
                            details.join(' · '),
                            maxLines: lines - titleLines,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.labelSmall?.copyWith(color: fg, height: 1.25),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
