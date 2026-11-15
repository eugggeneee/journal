import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/overview.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';

/// Главная карточка дня: что идёт сейчас и что дальше, сколько осталось, сколько пар пройдено,
/// когда кончается день и сколько часов пропущено. Для другого дня показывает его сводку.
/// Внизу действие «Весь день» с меню (сокращённый день, пометка): всё в одном месте и в одно нажатие.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.date,
    required this.slots,
    required this.profile,
    required this.store,
    required this.status,
    required this.onShortDay,
    required this.onMark,
  });
  final DateTime date;
  final List<LessonSlot> slots;
  final BellProfile profile;
  final AppStore store;

  /// Подпись об источнике данных: «Обновлено в 12:30», «Сохранено на устройстве».
  final String status;
  final VoidCallback onShortDay;
  final VoidCallback onMark;

  LessonSlot? _slot(int? n) {
    if (n == null) return null;
    for (final s in slots) {
      if (s.number == n) return s;
    }
    return null;
  }

  /// Ближайшая пара после номера [n].
  LessonSlot? _after(int n) {
    LessonSlot? best;
    for (final s in slots) {
      if (s.number > n && (best == null || s.number < best.number)) best = s;
    }
    return best;
  }

  LessonSlot? _first() {
    LessonSlot? best;
    for (final s in slots) {
      if (best == null || s.number < best.number) best = s;
    }
    return best;
  }

  String _title(LessonSlot s) => s.subjects.map(store.subjectName).join(' / ');

  String _place(LessonSlot s) => [
        for (final e in s.entries) [LessonCard.roomText(e.room), e.teacher].where((x) => x.isNotEmpty).join(' · '),
      ].where((x) => x.isNotEmpty).join(' / ');

  static String _big(int m) => m >= 60 ? '${m ~/ 60} ч ${m % 60}' : '$m';

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final now = DateTime.now();
    final minute = now.hour * 60 + now.minute;
    final diff = dayDiff(date, today());
    final isToday = diff == 0;

    final bells = [for (final s in slots) profile[s.number]].whereType<BellSlot>().toList();
    int? from;
    int? to;
    if (bells.isNotEmpty) {
      from = bells.map((b) => b.start).reduce((a, b) => a < b ? a : b);
      to = bells.map((b) => b.end).reduce((a, b) => a > b ? a : b);
    }
    final clock = isToday ? dayClock(profile, [for (final s in slots) s.number], minute) : null;
    final live = clock != null && clock.phase != DayPhase.none;

    final marked = [for (final s in slots) if (store.absenceFor(date, s.number) != null) s];
    final allMarked = slots.isNotEmpty && marked.length == slots.length;
    final hours = marked.fold<int>(0, (a, s) => a + (store.absenceFor(date, s.number)?.hours ?? 0));
    final shortDay = store.markFor(date, 0)?.label == kShortDayMark;

    var done = 0;
    if (diff < 0) {
      done = slots.length;
    } else if (isToday) {
      for (final s in slots) {
        final b = profile[s.number];
        if (b != null && minute >= b.end) done++;
      }
    }

    var tone = diff < 0 ? Tone(cs.secondaryContainer, cs.onSecondaryContainer) : Tone(cs.primaryContainer, cs.onPrimaryContainer);
    var accent = diff < 0 ? cs.secondary : cs.primary;
    var caption = 'Расписание дня';
    String? range = (from != null && to != null) ? shortRange(from, to) : null;
    var title = pairsText(slots.length);
    var sub = '';
    String? lead;
    int? left;
    double? progress;
    String? upNext;
    var phaseKey = 'calm-${ymd(date)}';

    if (live) {
      final c = clock;
      final cur = _slot(c.pair);
      final next = _slot(c.next);
      final curBell = c.pair == null ? null : profile[c.pair!];
      final nextBell = c.next == null ? null : profile[c.next!];
      phaseKey = '${c.phase.name}-${c.pair}-${c.next}';
      switch (c.phase) {
        case DayPhase.none:
          break;
        case DayPhase.lesson:
          if (cur != null && curBell != null) {
            caption = 'Идёт сейчас · ${cur.number} пара';
            range = shortRange(curBell.start, curBell.end);
            title = _title(cur);
            sub = _place(cur);
            lead = 'до конца';
            left = c.left;
            progress = c.progress;
            final n = _after(cur.number);
            if (n != null) {
              final b = profile[n.number];
              upNext = 'Потом: ${n.number} пара${b == null ? '' : ' в ${fmtMin(b.start)}'} · ${_title(n)}';
            }
          }
        case DayPhase.innerBreak:
          if (cur != null && curBell != null) {
            final word = innerBreakWord(curBell);
            tone = curBell.lunchInside ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.secondaryContainer, cs.onSecondaryContainer);
            accent = curBell.lunchInside ? cs.tertiary : cs.secondary;
            caption = '${word[0].toUpperCase()}${word.substring(1)} внутри ${cur.number} пары';
            range = shortRange(curBell.breakStart!, curBell.breakEnd!);
            title = _title(cur);
            sub = 'Дальше вторая половина в ${fmtMin(curBell.breakEnd!)}';
            lead = 'до конца';
            left = c.left;
            progress = c.progress;
          }
        case DayPhase.gap:
          if (next != null && nextBell != null && curBell != null) {
            final lunch = c.pair != null && profile.isLunchAfter(c.pair!);
            final window = next.number - (c.pair ?? next.number) > 1;
            tone = lunch ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.secondaryContainer, cs.onSecondaryContainer);
            accent = lunch ? cs.tertiary : cs.secondary;
            caption = lunch ? 'Обед' : (window ? 'Окно' : 'Перерыв');
            range = shortRange(curBell.end, nextBell.start);
            title = 'Дальше: ${_title(next)}';
            sub = ['${next.number} пара в ${fmtMin(nextBell.start)}', _place(next)].where((x) => x.isNotEmpty).join(' · ');
            lead = 'через';
            left = c.left;
            progress = c.progress;
          }
        case DayPhase.before:
          if (next != null && nextBell != null) {
            tone = Tone(cs.secondaryContainer, cs.onSecondaryContainer);
            accent = cs.secondary;
            caption = 'Скоро начало';
            range = fmtMin(nextBell.start);
            title = 'Первая пара: ${_title(next)}';
            sub = ['${next.number} пара', _place(next)].where((x) => x.isNotEmpty).join(' · ');
            lead = 'через';
            left = c.left;
          }
        case DayPhase.after:
          final lastBell = c.pair == null ? null : profile[c.pair!];
          tone = Tone(cs.tertiaryContainer, cs.onTertiaryContainer);
          accent = cs.tertiary;
          caption = 'На сегодня всё';
          range = lastBell == null ? null : fmtMin(lastBell.end);
          title = 'Пары закончились';
          sub = lastBell == null ? '' : 'Последняя закончилась в ${fmtMin(lastBell.end)}';
      }
    } else {
      final first = _first();
      if (first != null) {
        final b = profile[first.number];
        sub = ['Первая: ${_title(first)}', if (b != null) 'в ${fmtMin(b.start)}'].join(' ');
      } else {
        title = 'Занятий нет';
      }
    }

    final fg = tone.fg;
    const figures = [FontFeature.tabularFigures()];

    final top = Column(
      key: ValueKey(phaseKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700))),
          if (range != null) Text(range, style: tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700, fontFeatures: figures)),
        ]),
        const SizedBox(height: 8),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.headlineSmall?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.15)),
        if (sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.85))),
          ),
        if (left != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$lead ', style: tt.titleMedium?.copyWith(color: fg)),
              AnimatedNumber(
                value: left.toDouble(),
                format: (v) => _big(v.round()),
                style: tt.displaySmall?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.05),
              ),
              Text(' мин', style: tt.titleMedium?.copyWith(color: fg)),
            ]),
          ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: context.motion(Motion.long),
              curve: Motion.standard,
              builder: (context, v, _) => Bar(value: v, color: accent, height: 10, track: fg.withValues(alpha: 0.14)),
            ),
          ),
      ],
    );

    final study = bells.fold<int>(0, (a, b) => a + b.minutes);
    final stats = <_Stat>[
      if (live) _Stat('$done из ${slots.length}', 'пройдено') else if (study > 0) _Stat(spanText(study), 'на парах'),
      if (live && to != null) _Stat(fmtMin(to), 'конец дня') else if (!live && from != null) _Stat(fmtMin(from), 'начало'),
      _Stat('$hours ч', hours > 0 ? 'пропущено' : 'без пропусков'),
    ];

    final footerText = upNext ?? status;
    final footerIcon = upNext != null ? Icons.schedule_rounded : Icons.cloud_done_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HeroCard(
        tone: tone,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Smooth(child: top),
          const SizedBox(height: 16),
          _StatsPanel(stats: stats, fg: fg),
          const SizedBox(height: 12),
          Row(children: [
            Icon(footerIcon, size: 16, color: fg.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Expanded(
              child: Swap(
                child: Text(
                  footerText,
                  key: ValueKey(footerText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.85)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _WholeDaySplit(
              fg: fg,
              allMarked: allMarked,
              shortDay: shortDay,
              enabled: slots.isNotEmpty,
              onWholeDay: () => toggleWholeDay(context, store, date, slots),
              onShortDay: onShortDay,
              onMark: onMark,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Stat {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
}

/// Три коротких показателя дня в одной плашке: число и подпись под ним.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats, required this.fg});
  final List<_Stat> stats;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) Container(width: 1, height: 28, color: fg.withValues(alpha: 0.16)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stats[i].value,
                    maxLines: 1,
                    softWrap: false,
                    style: tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stats[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8)),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Split button: слева основное действие, справа стрелка с меню. Половинки разделены зазором 2 dp
/// и скруглены сильнее с внешней стороны. Цвета берутся у карточки, на которой кнопка стоит.
class _WholeDaySplit extends StatelessWidget {
  const _WholeDaySplit({
    required this.fg,
    required this.allMarked,
    required this.shortDay,
    required this.enabled,
    required this.onWholeDay,
    required this.onShortDay,
    required this.onMark,
  });
  final Color fg;
  final bool allMarked;
  final bool shortDay;
  final bool enabled;
  final VoidCallback onWholeDay;
  final VoidCallback onShortDay;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    const outer = Radius.circular(22);
    const inner = Radius.circular(6);
    final d = context.motion(Motion.short);
    final bg = fg.withValues(alpha: 0.14);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: outer, right: inner)),
        ),
        icon: AnimatedSwitcher(
          duration: d,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: Icon(allMarked ? Icons.event_available_rounded : Icons.event_busy_rounded, key: ValueKey(allMarked), size: 20),
        ),
        // Ширина кнопки меняется вместе с подписью плавно, а не рывком.
        label: AnimatedSize(
          duration: d,
          curve: Motion.standard,
          child: Swap(
            alignment: Alignment.center,
            child: Text(allMarked ? 'Снять день' : 'Весь день', key: ValueKey(allMarked)),
          ),
        ),
        onPressed: enabled
            ? () {
                Haptics.selection();
                onWholeDay();
              }
            : null,
      ),
      const SizedBox(width: 2),
      MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
          ),
        ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.timelapse_rounded),
            trailingIcon: shortDay ? Icon(Icons.check_rounded, color: cs.primary) : null,
            onPressed: onShortDay,
            child: const Text('Сокращённый день'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.bookmark_add_outlined),
            onPressed: onMark,
            child: const Text('Пометка на день'),
          ),
        ],
        builder: (context, controller, _) => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: inner, right: outer)),
          ),
          onPressed: () {
            Haptics.selection();
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Semantics(
            label: 'Ещё действия дня',
            child: AnimatedRotation(
              turns: controller.isOpen ? 0.5 : 0,
              duration: d,
              curve: Motion.standard,
              child: const Icon(Icons.arrow_drop_down_rounded, size: 28),
            ),
          ),
        ),
      ),
    ]);
  }
}
