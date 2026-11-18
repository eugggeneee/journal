import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../schedule/lesson_card.dart';
import '../schedule/whole_day_split.dart';
import '../settings/bells_page.dart';
import 'day_bar.dart';
import 'hero_surface.dart';

class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.now,
    required this.slots,
    required this.profile,
    required this.store,
    required this.onShortDay,
    required this.onMark,
    required this.header,
    required this.onOpenDay,
    this.metrics,
  });
  final DateTime now;
  final List<LessonSlot> slots;
  final BellProfile profile;
  final AppStore store;
  final VoidCallback onShortDay;
  final VoidCallback onMark;
  final VoidCallback onOpenDay;
  final Widget Function(Color fg) header;
  final Widget? metrics;

  String _title(LessonSlot slot) => slot.subjects.map(store.subjectName).join(' / ');
  String _place(LessonSlot slot) => [
    for (final e in slot.entries) [LessonCard.roomText(e.room), e.teacher].where((v) => v.isNotEmpty).join(' · '),
  ].where((v) => v.isNotEmpty).join(' / ');

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final tone = Tone(cs.primary, cs.onPrimary);
    final fg = tone.fg;
    final minute = now.hour * 60 + now.minute;
    final numbers = slots.map((s) => s.number).toList();
    final completeTimes = numbers.every((n) => profile[n] != null);
    final clock = dayClock(profile, numbers, minute);
    final current = slots.where((s) => s.number == clock.pair).firstOrNull;
    final following = slots.where((s) => s.number > (clock.pair ?? 0)).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final next = clock.next == null ? following.firstOrNull : slots.where((s) => s.number == clock.next).firstOrNull;
    final inLesson = clock.phase == DayPhase.lesson || clock.phase == DayPhase.innerBreak;
    final focus = inLesson ? current : next;
    final bell = current == null ? null : profile[current.number];
    final beforeBreak = clock.phase == DayPhase.lesson && bell != null && bell.hasBreak && minute < bell.breakStart!;
    final left = beforeBreak ? bell.breakStart! - minute : clock.left;
    final reason = switch (clock.phase) {
      DayPhase.lesson when beforeBreak => bell.lunchInside ? 'до обеда' : 'до перерыва',
      DayPhase.lesson when next == null => 'до конца занятий',
      DayPhase.lesson => profile.isLunchAfter(current!.number) ? 'до обеда' : 'до конца пары',
      DayPhase.innerBreak => 'до продолжения',
      DayPhase.gap => 'до пары',
      DayPhase.before => 'до начала',
      _ => '',
    };
    final caption = switch (clock.phase) {
      DayPhase.lesson => 'Идёт сейчас',
      DayPhase.innerBreak => bell!.lunchInside ? 'Обед внутри пары' : 'Перерыв внутри пары',
      DayPhase.gap => gapBetween(profile, current!.number, next!.number) ?? 'Перерыв',
      DayPhase.before => 'Первая пара',
      DayPhase.after => completeTimes ? 'На сегодня всё' : 'Без времени звонков',
      DayPhase.none => 'Сегодня',
    };
    final title = clock.phase == DayPhase.after && completeTimes
        ? 'Пары закончились'
        : focus != null
        ? _title(focus)
        : pairsText(slots.length);
    final bells = numbers.map((n) => profile[n]).whereType<BellSlot>().toList();
    final remaining = bells.where((b) => minute < b.end).length;
    final end = bells.isEmpty ? null : bells.map((b) => b.end).reduce((a, b) => a > b ? a : b);
    final folded = store.settings.dayCardFolded;

    return HeroSurface(
      tone: tone,
      header: header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (focus != null) ...[
                CookieIcon(
                  size: 54,
                  bg: fg,
                  glyph: Text(
                    '${focus.number}',
                    style: tt.headlineSmall?.copyWith(color: tone.bg, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: InkWell(
                  onTap: onOpenDay,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caption, style: tt.labelLarge?.copyWith(color: fg)),
                      Text(
                        title,
                        style: tt.headlineSmall?.copyWith(color: fg, height: 1.1, fontWeight: FontWeight.w800),
                      ),
                      if (!folded && focus != null && _place(focus).isNotEmpty)
                        Text(_place(focus), style: tt.bodyMedium?.copyWith(color: fg.withValues(alpha: .85))),
                      if (folded && reason.isNotEmpty)
                        Text('$left мин $reason', style: tt.bodyMedium?.copyWith(color: fg)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: folded ? 'Развернуть карточку' : 'Свернуть карточку',
                color: fg,
                icon: Icon(folded ? Icons.unfold_more_rounded : Icons.unfold_less_rounded),
                onPressed: () {
                  Haptics.selection();
                  store.setDayCardFolded(!folded);
                },
              ),
            ],
          ),
          if (!folded && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Semantics(
                label: '$left мин $reason в ${fmtMin(minute + left)}',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$left',
                          style: TextStyle(
                            fontSize: 148,
                            height: .93,
                            letterSpacing: -8,
                            fontWeight: FontWeight.w900,
                            color: fg,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'мин',
                              style: tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1),
                            ),
                            Text(
                              '$reason\nв ${fmtMin(minute + left)}',
                              style: tt.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (end != null) ...[
            const SizedBox(height: 12),
            if (!folded)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    Text(
                      'Ход дня',
                      style: tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [if (remaining > 0) 'ещё ${pairsText(remaining)}', 'до ${fmtMin(end)}'].join(' · '),
                      style: tt.labelLarge?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            DayBar(slots: slots, profile: profile, minute: minute, fg: fg, bg: tone.bg, compact: folded),
          ],
          if (!folded) ...[
            if (!completeTimes && slots.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: fg),
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => BellsPage(initialKey: store.bellKeyOn(now)))),
                  label: const Text('Выбрать звонки'),
                ),
              ),
            if (inLesson && next != null) ...[
              const SizedBox(height: 14),
              Material(
                color: fg.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
                child: ListTile(
                  onTap: onOpenDay,
                  textColor: fg,
                  iconColor: fg,
                  leading: Text(
                    profile[next.number] == null ? '${next.number}' : fmtMin(profile[next.number]!.start),
                    style: tt.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w800),
                  ),
                  title: Text(_title(next)),
                  subtitle: Text(['Дальше', _place(next)].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ],
            const SizedBox(height: 14),
            WholeDaySplit(
              fg: fg,
              enabled: slots.isNotEmpty,
              allMarked: slots.isNotEmpty && slots.every((s) => store.absenceFor(now, s.number) != null),
              shortDay: store.markFor(now, 0)?.label == kShortDayMark,
              onWholeDay: () => toggleWholeDay(context, store, now, slots),
              onShortDay: onShortDay,
              onMark: onMark,
            ),
          ],
          if (metrics != null) ...[const SizedBox(height: 14), metrics!],
        ],
      ),
    );
  }
}
