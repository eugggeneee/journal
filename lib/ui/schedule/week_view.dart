import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/schedule/schedule_service.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';
import 'lesson_sheet.dart';

/// Неделя на широком экране: шесть колонок (пн–сб), в каждой пары дня с временем, названием и аудиторией.
/// Нажатие на заголовок дня открывает его целиком, нажатие на пару открывает подробности.
class WeekView extends StatelessWidget {
  const WeekView({super.key, required this.refresh, required this.selected, required this.onShift, required this.onOpenDay});
  final DateTime selected;
  final int refresh;
  final ValueChanged<int> onShift;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final store = StoreScope.of(context);
    final monday = addDays(selected, -(selected.weekday - 1));
    final saturday = addDays(monday, 5);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          IconButton(tooltip: 'Предыдущая неделя', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => onShift(-1)),
          Expanded(
            child: Center(
              child: Text(
                '${shortDate(monday)} – ${shortDate(saturday)}',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
              ),
            ),
          ),
          IconButton(tooltip: 'Следующая неделя', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => onShift(1)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, kFabClearance),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Appear(
                    index: i,
                    child: _WeekDay(refresh: refresh, key: ValueKey('${ymd(addDays(monday, i))}|${store.settings.group}'), date: addDays(monday, i), onOpen: onOpenDay),
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _WeekDay extends StatefulWidget {
  const _WeekDay({super.key, required this.refresh, required this.date, required this.onOpen});
  final DateTime date;
  final ValueChanged<DateTime> onOpen;
  final int refresh;
  @override
  State<_WeekDay> createState() => _WeekDayState();
}

class _WeekDayState extends State<_WeekDay> {
  DayState? _st;
  bool _started = false;
  int _generation = 0;

  @override
  void didUpdateWidget(_WeekDay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refresh != oldWidget.refresh) _load(force: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load({bool force = false}) {
    final generation = ++_generation;
    final store = StoreScope.of(context);
    final cached = store.cachedSchedule(store.settings.group, widget.date);
    if (cached != null) _st = DayState(DayStatus.ok, schedule: cached, fromCache: true);
    StoreScope.repoOf(context).load(widget.date, force: force).then((s) {
      if (mounted && generation == _generation) setState(() => _st = s);
    }).catchError((_) {
      if (mounted && generation == _generation) setState(() => _st = const DayState(DayStatus.error));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final store = StoreScope.of(context);
    final d = widget.date;
    final isToday = sameDay(d, today());
    final st = _st;
    final slots = [...?st?.schedule?.slots]..sort((a, b) => a.number.compareTo(b.number));

    Widget body;
    if (st == null) {
      body = const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))));
    } else if (st.status != DayStatus.ok) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Text(
          st.status == DayStatus.sunday ? 'Выходной' : (st.status == DayStatus.notPublished ? 'Ещё не опубликовано' : 'Нет данных'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    } else if (slots.isEmpty) {
      body = Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Пар нет', textAlign: TextAlign.center, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)));
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in slots) _WeekTile(date: d, slot: s, store: store),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        label: longDate(d),
        excludeSemantics: true,
        child: Material(
          color: isToday ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Haptics.selection();
              widget.onOpen(d);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(weekdayShort(d), style: tt.labelMedium?.copyWith(color: isToday ? cs.onPrimary.withValues(alpha: 0.85) : cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  Text('${d.day}', style: tt.titleLarge?.copyWith(color: isToday ? cs.onPrimary : cs.onSurface, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      body,
    ]);
  }
}

/// Компактная карточка пары для колонки недели: время, название целиком, аудитория и преподаватель.
class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.date, required this.slot, required this.store});
  final DateTime date;
  final LessonSlot slot;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final key = slot.subjects.isEmpty ? '' : slot.subjects.first;
    final accent = hueAccent(context, subjectHue(key));
    final absence = store.absenceFor(date, slot.number);
    final edge = absence != null ? absenceAccent(context, excused: absence.excused) : accent;
    final bg = absence != null
        ? absenceTone(context, excused: absence.excused).bg.withValues(alpha: 0.55)
        : Color.alphaBlend(accent.withValues(alpha: 0.09), cs.surfaceContainerLow);
    final bell = store.bellFor(date, slot.number);
    final place = [
      for (final e in slot.entries) [LessonCard.roomText(e.room), e.teacher].where((x) => x.isNotEmpty).join(' · '),
    ].where((x) => x.isNotEmpty).join(' / ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            showLessonSheet(context, date, slot);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: edge, width: 4))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  [if (bell != null) fmtMin(bell.start), '${slot.number} пара'].join(' · '),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 2),
                Text(slot.subjects.map(store.subjectName).join(' / '), style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                if (place.isNotEmpty) Text(place, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, height: 1.25)),
                if (absence != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(absence.excused ? 'Уважительная' : 'Пропуск', style: tt.labelSmall?.copyWith(color: edge, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
